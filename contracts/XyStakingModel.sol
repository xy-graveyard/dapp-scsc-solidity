pragma solidity >=0.5.0 <0.6.0;

import "./XyBlockProducer.sol";
import "./token/ERC20/SafeERC20.sol";
import "./XyGovernance.sol";
import "./utils/SafeMath.sol";

contract XyStakingModel is IXyVotingData {
    using SafeMath for uint;
    
    // SafeERC20 wrapped token contract for stake denomination
    address public xyoToken;
    // 721 contract that we reference for all things staked
    XyBlockProducer public blockProducerContract;
    // Contract that governs parameters and actions that affect staking
    XyGovernance public govContract;
    // Active stake is total block producer stake for consensus and voting
    uint public totalActiveStake;
    // Cooldown stake is total non-block producer stake for voting
    uint public totalCooldownStake;
    // The stake taken from holders due to penalizing actions
    uint public penaltyStake;
    // Mapping from staking model id to stake metadata     
    mapping (bytes32 => Stake) public stakeData;
    // The staking token id arrays by staker/stakee
    mapping (address => bytes32[]) public stakeeToStakingIds;
    mapping (address => bytes32[]) public stakerToStakingIds;
    // holds staking token index into staking arrays by staker/stakee
    mapping (bytes32 => uint) public stakingStakeeIndex;
    mapping (bytes32 => uint) public stakingStakerIndex;
    // Cached total stake amounts by staker/stakee
    mapping (address => StakeAmounts) public stakeeStake;
    mapping (address => StakeAmounts) public stakerStake;

    // Stake data associated with all staking tokens
    struct Stake {
        uint amount;            // amount of token on this stake
        uint stakeBlock;        // the creation block
        uint unstakeBlock;      // if unstaked, non-zero unstake block
        address stakee;         // who was staked
        address staker;         // who owns the stake
        bool isActivated;       // qualifies for block production and governance
        bool isCooledDown;      // qualifies for governance
    } 

    // Cached Total/Active stake amounts
    struct StakeAmounts {
        uint totalStake;
        uint activeStake;
        uint cooldownStake;
        uint totalUnstake;
    }

    // StakeEvent transitions
    enum StakeTransition { STAKED, ACTIVATED, COOLED, UNSTAKED, WITHDREW }

    
    /** EVENTS */
    event StakeEvent(
        bytes32 stakingId,
        uint amount,
        address staker,
        address stakee,
        StakeTransition transition
    );

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier whenActive() {
        require(govContract.get("xyPaused") == 0, "Staking is Paused");
        _;
    }

    /** Creates a Staking token contract 
        @param _token - The ERC20 token to stake with 
        @param _blockProducers - The block producer list
        @param _governanceContract - The contract that governs the govContract and actions of the system
    */
    function init(
        address _token,
        address _blockProducers,
        address _governanceContract
    )
        internal
    {
        xyoToken = _token;
        blockProducerContract = XyBlockProducer(_blockProducers);
        govContract = XyGovernance(_governanceContract);
    }

    /** Increase and decrease cached stake amounts */
    function updateCacheOnStake(uint amount, address stakee) internal {
        stakeeStake[stakee].totalStake = stakeeStake[stakee].totalStake.add(amount);
        stakerStake[msg.sender].totalStake = stakerStake[msg.sender].totalStake.add(amount);
    }
    function updateCacheOnActivate(uint amount, address stakee) internal {
        stakeeStake[stakee].activeStake = stakeeStake[stakee].activeStake.add(amount);
        stakerStake[msg.sender].activeStake = stakerStake[msg.sender].activeStake.add(amount);
        totalActiveStake = totalActiveStake.add(amount);
    }
    function updateCacheOnCoolDown(uint amount, address stakee) internal {
        stakeeStake[stakee].cooldownStake = stakeeStake[stakee].cooldownStake.add(amount);
        stakerStake[msg.sender].cooldownStake = stakerStake[msg.sender].cooldownStake.add(amount);
        totalCooldownStake = totalCooldownStake.add(amount);
    }
    function updateCacheOnUnstake(Stake memory data) internal {
        reduceStake(data, data.amount);
        stakeeStake[data.stakee].totalUnstake = stakeeStake[data.stakee].totalUnstake.add(data.amount);
        stakerStake[data.staker].totalUnstake = stakerStake[data.staker].totalUnstake.add(data.amount);
    }
    function updateCacheOnWithdraw(uint amount, address stakee) internal {
        stakeeStake[stakee].totalUnstake = stakeeStake[stakee].totalUnstake.sub(amount);
        stakerStake[msg.sender].totalUnstake = stakerStake[msg.sender].totalUnstake.sub(amount);
    }

    function reduceStake(Stake memory data, uint quantity) internal {
        stakeeStake[data.stakee].totalStake = stakeeStake[data.stakee].totalStake.sub(quantity);
        stakerStake[data.staker].totalStake = stakerStake[data.staker].totalStake.sub(quantity);
        if (data.isActivated) {
            stakeeStake[data.stakee].activeStake = stakeeStake[data.stakee].activeStake.sub(quantity);
            stakerStake[data.staker].activeStake = stakerStake[data.staker].activeStake.sub(quantity);
            totalActiveStake = totalActiveStake.sub(quantity);
        }
        if (data.isCooledDown) {
            stakeeStake[data.stakee].cooldownStake = stakeeStake[data.stakee].cooldownStake.sub(quantity);
            stakerStake[data.staker].cooldownStake = stakerStake[data.staker].cooldownStake.sub(quantity);
            totalCooldownStake = totalCooldownStake.sub(quantity);
        }
    }

    /** 
        Call this when it's time to resolve a passed governance action
        @param stakee the staked item receiving action
        @param startIndex if a batchable action, where to start
        @param batchSize if batchable action, batchSize
    */
    function resolveGovernanceAction (
        address stakee, 
        uint startIndex, 
        uint batchSize
    ) 
        public 
    {
        (,uint penalty,XyGovernance.ActionType actionType,bool accepted) = govContract.actions(stakee);
        require(accepted == true, "action must be accepted");
        // unstake action
        if (actionType == XyGovernance.ActionType.UNSTAKE) {
            _unstakeGovernanceAction(stakee, startIndex, batchSize, penalty);
        } else if (actionType == XyGovernance.ActionType.REMOVE_BP) {
            // unstake all with no penalty
            _unstakeGovernanceAction(stakee, startIndex, batchSize, 0);
            // burn stakee 721
            blockProducerContract.remove(stakee);
        } else if (actionType == XyGovernance.ActionType.ADD_BP) {
            blockProducerContract.create(stakee);
            govContract.resolveAction(stakee);
        } 

        if (isUnstakeAction(actionType) && stakeeStake[stakee].activeStake == 0) {
            govContract.resolveAction(stakee);
        }
    }

    function _unstakeGovernanceAction(
        address stakee, 
        uint startIndex, 
        uint batchSize, 
        uint penalty
    ) 
        private
    {
        for (uint i = startIndex; i < batchSize + startIndex; i++) {
            bytes32 token = stakeeToStakingIds[stakee][i];
            Stake storage data = stakeData[token];
            if (data.unstakeBlock == 0) {
                if (penalty > 0) {
                    uint penaltyAmount = penalty.mul(data.amount).div(100);
                    reduceStake(data, penaltyAmount);
                    penaltyStake.add(penaltyAmount);
                }
                updateCacheOnUnstake(data);
                data.unstakeBlock = block.number;
            }
        }
    }

    /* 
        Is this actiontype an action that must unstake any stake on the address
    */
    function isUnstakeAction (XyGovernance.ActionType actionType) 
        pure public 
        returns (bool) 
    {
        return (actionType == XyGovernance.ActionType.UNSTAKE  || actionType == XyGovernance.ActionType.REMOVE_BP);
    }

    function stakeMultiple (address spender, address[] memory stakers, address[] memory stakees, uint[] memory amounts) internal {
        for (uint i = 0; i < stakees.length; i++) {
            stakeFrom(spender, stakers[i], stakees[i], amounts[i]);
        }
    }

    function stakeFrom (
        address spender, 
        address staker, 
        address stakee, 
        uint amount
    )  
        internal
        returns (bytes32) 
    {
        // this causes revert if this contract has not been approved for transferring
        SafeERC20.transferFrom(xyoToken, spender, address(this), amount);

        require(govContract.hasUnresolvedAction(stakee) == false, "All actions on stakee must be resolved");
        updateCacheOnStake(amount, stakee);

        // random generated token id
        bytes32 newToken = keccak256(abi.encodePacked(stakee, staker, block.number));
        Stake memory data = Stake(
            amount,         // amount
            block.number,   // stakeBlock
            0,              // unstakeBlock
            stakee,         // stakee 
            staker,         // staker
            false,          // isActivated
            false           // isCooledDown
        );

        // Store the staking data
        stakingStakeeIndex[newToken] = stakeeToStakingIds[stakee].length;
        stakeeToStakingIds[stakee].push(newToken);
        stakingStakerIndex[newToken] = stakerToStakingIds[staker].length;
        stakerToStakingIds[staker].push(newToken);
        stakeData[newToken] = data;

        emit StakeEvent(newToken, amount, staker, stakee, StakeTransition.STAKED);
        return newToken;
    }

    /** 
        Adds stake to a stakable token id
        @dev This contract must be approved to transfer tokens by token holder
        @param stakee - the stakable address 
        @param amount - the amount to stake
    */
    function stake(address stakee, uint amount)
        whenActive 
        public
        returns (bytes32)
    {
        return stakeFrom(msg.sender, msg.sender, stakee, amount);
    }
    
    function _requireStakeCooledDown(bytes32 stakingId)
        private view
        returns (Stake storage)
    {
        Stake storage data = stakeData[stakingId];
        require(data.staker == msg.sender, "Only the staker can activate");
        require(data.stakeBlock + govContract.get("xyStakeCooldown") < block.number, "Not ready to activate stake yet");
        require(data.unstakeBlock == 0, "Cannot activate unstake");

        return data;
    }

    /**
        @dev Mark stake as cooled down so we can cache totals for voting
        @param stakingId - the tokenId of the staking token
    */
    function cooldownStake(bytes32 stakingId) 
        whenActive
        public
    {
        Stake storage data = _requireStakeCooledDown(stakingId);
        require(data.isCooledDown == false, "cannot re-cooldown stake");
        require(blockProducerContract.exists(data.stakee) == false, "Only non BPs can be cooled down");
        data.isCooledDown = true;
        updateCacheOnCoolDown(data.amount, data.stakee);
        emit StakeEvent(stakingId, data.amount, msg.sender, data.stakee, StakeTransition.COOLED);
    }

    /**
        @dev Activate stake on a block producer
        @param stakingId - the tokenId of the staking token
    */
    function activateStake(bytes32 stakingId) 
        whenActive
        public 
    {
        Stake storage data = _requireStakeCooledDown(stakingId);
        require(data.isActivated == false, "cannot re-activate stake");
        require(blockProducerContract.exists(data.stakee) == true, "Only BPs can be activated");
        data.isActivated = true;
        updateCacheOnActivate(data.amount, data.stakee);
        emit StakeEvent(stakingId, data.amount, msg.sender, data.stakee, StakeTransition.ACTIVATED);
    }

    /** 
        unstake a specific previous stake 
        @param stakingId - the tokenId of the staking token
    */
    function unstake(bytes32 stakingId)
        whenActive
        public
    {
        Stake storage data = stakeData[stakingId];
        require(data.staker == msg.sender, "Only the staker can unstake a stake");
        require(data.stakeBlock + govContract.get("xyStakeCooldown") < block.number, "Staking needs to cooldown");
        require(data.unstakeBlock == 0, "Cannot re-unstake");
        updateCacheOnUnstake(data);
        data.isActivated = false;
        data.isCooledDown = false;
        data.unstakeBlock = block.number;
        emit StakeEvent(stakingId, data.amount, data.staker, data.stakee, StakeTransition.UNSTAKED);
    }

    /** 
        Internally used to remove token and adjust state array with no iterating 
        @param stakingId - the stakingId to remove
    */
    function removeStakeeData(bytes32 stakingId) 
        internal 
    {
        address stakee = stakeData[stakingId].stakee;
        uint stakeeIndex = stakingStakeeIndex[stakingId];
        uint lastStakeeIndex = stakeeToStakingIds[stakee].length - 1;
        bytes32 lastStakeeId = stakeeToStakingIds[stakee][lastStakeeIndex];
            
        stakeeToStakingIds[stakee][stakeeIndex] = lastStakeeId;
        stakeeToStakingIds[stakee][lastStakeeIndex] = 0;

        stakeeToStakingIds[stakee].length--;
        delete stakingStakeeIndex[stakingId];
        stakingStakeeIndex[lastStakeeId] = stakeeIndex;
    }

    /** 
        Internally used to remove token and adjust state array with no iterating 
        @param stakingId - the stakingId to remove
    */
    function removeStakerData(bytes32 stakingId) 
        internal 
    {
        address staker = stakeData[stakingId].staker;
        uint stakerIndex = stakingStakerIndex[stakingId];
        uint lastStakerIndex = stakerToStakingIds[staker].length - 1;
        bytes32 lastStakerId = stakerToStakingIds[staker][lastStakerIndex];
            
        stakerToStakingIds[staker][stakerIndex] = lastStakerId;
        stakerToStakingIds[staker][lastStakerIndex] = 0;

        stakerToStakingIds[staker].length--;
        delete stakingStakerIndex[stakingId];
        stakingStakerIndex[lastStakerId] = stakerIndex;
    }

    /** 
        Withdraw a single token's stake by token id, removes staking token
        @param stakingId - the tokenId of the staking token to remove
    */
    function withdrawStake(bytes32 stakingId)
      whenActive
      public 
    {
        Stake memory data = stakeData[stakingId];
        require(govContract.hasUnresolvedAction(data.stakee) == false, "All actions on stakee must be resolved");
        require(data.staker == msg.sender, "Only owner can withdraw");
        require(data.unstakeBlock > 0 && (data.unstakeBlock + govContract.get("xyUnstakeCooldown")) < block.number, "Not ready for withdraw");
        emit StakeEvent(stakingId, data.amount, data.staker, data.stakee, StakeTransition.WITHDREW);
        removeStakeeData(stakingId);
        removeStakerData(stakingId);
        updateCacheOnWithdraw(data.amount, data.stakee);
        SafeERC20.transfer(xyoToken, msg.sender, data.amount);
    }

    /** 
        Withdraw a batch of first avaliable staking tokens
        @param batchLimit - Allows iterating over withdrawing due to gas limits
        if batchlimit is 0, try withdrawing all available tokens (be prepared for out of gas if you've got > 50 tokens)
    */
    function withdrawManyStake(uint batchLimit)
        whenActive
        public
    {
        uint balance = numStakerStakes(msg.sender);
        uint limit = batchLimit > 0 ? batchLimit : balance;
        uint withdrawAmt = 0;
        bytes32[] memory removeArr = new bytes32[](limit);
        uint numremove = 0;
        for (uint i = 0; i < balance && i < limit; i++) {
            Stake memory data = stakeData[stakerToStakingIds[msg.sender][i]];

            if (data.unstakeBlock > 0 && (data.unstakeBlock + govContract.get("xyUnstakeCooldown")) < block.number && govContract.hasUnresolvedAction(data.stakee) == false) {
                removeArr[numremove] = stakerToStakingIds[msg.sender][i];      
                numremove++;
            }      
        }
        for (uint b = 0; b < numremove; b++) {
            removeStakeeData(removeArr[b]);
            removeStakerData(removeArr[b]);
            Stake memory data = stakeData[removeArr[b]];
            withdrawAmt += data.amount;
            updateCacheOnWithdraw(data.amount, data.stakee);
            emit StakeEvent(removeArr[b], data.amount, data.staker, data.stakee, StakeTransition.WITHDREW);
        }

        if (withdrawAmt > 0) {
            SafeERC20.transfer(xyoToken, msg.sender, withdrawAmt);
        }
    }

    /** Get the available unstake, counting only stakes that can be withdrawn */    
    function getAvailableStakerUnstake(address staker)
        external
        view
        returns(uint)
    {
        uint stakeTotal = 0;
        uint num = numStakerStakes(staker);
        for (uint i = 0; i < num; i++) {
            Stake memory data = stakeData[stakerToStakingIds[staker][i]];
            if (data.unstakeBlock > 0 && (data.unstakeBlock + govContract.get("xyUnstakeCooldown")) < block.number) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }

    /** Get the available unstake, counting only stakes that can be withdrawn */    
    function getAvailableStakeeUnstake(address stakee)
        external
        view
        returns(uint)
    {
        bytes32[] memory stakeList = stakeeToStakingIds[stakee];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            Stake memory data = stakeData[stakeList[i]];
            if (data.unstakeBlock > 0 && (data.unstakeBlock + govContract.get("xyUnstakeCooldown")) < block.number) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }

    /** Public getters */
    function numStakerStakes(address staker) public view returns (uint) {
        return stakerToStakingIds[staker].length;
    }
    function numStakeeStakes(address stakee) public view returns (uint) {
        return stakeeToStakingIds[stakee].length;
    }
    function totalStakeAndUnstake(address staker) public view returns (uint) {
        return stakerStake[staker].totalUnstake + stakerStake[staker].totalStake;
    }
    function totalVotingStake() external view returns (uint) {
        return totalCooldownStake.add(totalActiveStake);
    }
}