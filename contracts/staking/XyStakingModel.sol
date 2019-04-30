pragma solidity >=0.5.0 <0.6.0;

import "../XyBlockProducer.sol";
import "../token/ERC20/SafeERC20.sol";
import "../XyGovernance.sol";
import "../utils/SafeMath.sol";

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
    // The staking id arrays by staker/stakee
    mapping (address => bytes32[]) public stakeeToStakingIds;
    mapping (address => bytes32[]) public stakerToStakingIds;
    // holds staking index into staking arrays by staker/stakee
    mapping (bytes32 => uint) public stakingStakeeIndex;
    mapping (bytes32 => uint) public stakingStakerIndex;
    // Cached total stake amounts by staker/stakee
    mapping (address => StakeAmounts) public stakeeStake;
    mapping (address => StakeAmounts) public stakerStake;

    // Stake data associated with all stake
    struct Stake {
        uint amount;            // amount on this stake
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

    // mapping from stake id to bond id
    mapping (bytes32 => bytes32) public bondedStake;

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
    function updateCacheOnStake(Stake memory s) internal {
        stakeeStake[s.stakee].totalStake = stakeeStake[s.stakee].totalStake.add(s.amount);
        stakerStake[s.staker].totalStake = stakerStake[s.staker].totalStake.add(s.amount);
    }

    function updateCacheOnActivate(Stake memory s) internal {
        if (s.isCooledDown) {
            stakeeStake[s.stakee].cooldownStake = stakeeStake[s.stakee].cooldownStake.add(s.amount);
            stakerStake[s.staker].cooldownStake = stakerStake[s.staker].cooldownStake.add(s.amount);
            totalCooldownStake = totalCooldownStake.add(s.amount);
        } else {
            stakeeStake[s.stakee].activeStake = stakeeStake[s.stakee].activeStake.add(s.amount);
            stakerStake[s.staker].activeStake = stakerStake[s.staker].activeStake.add(s.amount);
            totalActiveStake = totalActiveStake.add(s.amount);
        }
    }
    function updateCacheOnUnstake(Stake storage s) internal {
        reduceStake(s, s.amount);
        stakeeStake[s.stakee].totalUnstake = stakeeStake[s.stakee].totalUnstake.add(s.amount);
        stakerStake[s.staker].totalUnstake = stakerStake[s.staker].totalUnstake.add(s.amount);
        s.isActivated = false;
        s.isCooledDown = false;
        s.unstakeBlock = block.number;
    }
    function updateCacheOnWithdraw(Stake memory s) internal {
        stakeeStake[s.stakee].totalUnstake = stakeeStake[s.stakee].totalUnstake.sub(s.amount);
        stakerStake[s.staker].totalUnstake = stakerStake[s.staker].totalUnstake.sub(s.amount);
    }  
    function reduceStake(Stake memory s, uint quantity) internal {
        stakeeStake[s.stakee].totalStake = stakeeStake[s.stakee].totalStake.sub(quantity);
        stakerStake[s.staker].totalStake = stakerStake[s.staker].totalStake.sub(quantity);
        if (s.isActivated) {
            stakeeStake[s.stakee].activeStake = stakeeStake[s.stakee].activeStake.sub(quantity);
            stakerStake[s.staker].activeStake = stakerStake[s.staker].activeStake.sub(quantity);
            totalActiveStake = totalActiveStake.sub(quantity);
        } else if (s.isCooledDown) {
            stakeeStake[s.stakee].cooldownStake = stakeeStake[s.stakee].cooldownStake.sub(quantity);
            stakerStake[s.staker].cooldownStake = stakerStake[s.staker].cooldownStake.sub(quantity);
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
            bytes32 stakingId = stakeeToStakingIds[stakee][i];
            Stake storage data = stakeData[stakingId];
            if (data.unstakeBlock == 0) {
                if (penalty > 0) {
                    uint penaltyAmount = penalty.mul(data.amount).div(100);
                    reduceStake(data, penaltyAmount);
                    penaltyStake.add(penaltyAmount);
                }
                updateCacheOnUnstake(data);
                emit StakeEvent(stakingId, data.amount, data.staker, data.stakee, StakeTransition.UNSTAKED);
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

    function stakeAndBond (bytes32 bondId, address issuer, address staker, address[] memory stakees, uint[] memory amounts) internal {
        require(stakees.length == amounts.length, "bad inputs");
        for (uint i = 0; i < stakees.length; i++) {
            bytes32 stakingId = stakeFrom(issuer, staker, stakees[i], amounts[i]);
            bondedStake[stakingId] = bondId;
            _activateStake(stakingId, blockProducerContract.exists(stakees[i]) != true);
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

        // pseudo-random generated id
        bytes32 stakingId = keccak256(abi.encodePacked(stakee, staker, block.number));
        Stake memory data = Stake(
            amount,         // amount
            block.number,   // stakeBlock
            0,              // unstakeBlock
            stakee,         // stakee 
            staker,         // staker
            false,          // isActivated
            false           // isCooledDown
        );
        
        updateCacheOnStake(data);

        // Store the staking data
        stakingStakeeIndex[stakingId] = stakeeToStakingIds[stakee].length;
        stakeeToStakingIds[stakee].push(stakingId);
        stakingStakerIndex[stakingId] = stakerToStakingIds[staker].length;
        stakerToStakingIds[staker].push(stakingId);
        stakeData[stakingId] = data;

        emit StakeEvent(stakingId, amount, staker, stakee, StakeTransition.STAKED);
        return stakingId;
    }

    /** 
        Create new stake on a stakee
        @dev This contract must be approved to transfers by holder
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
        if (bondedStake[stakingId] == 0) {
            require(data.staker == msg.sender, "Only the staker can activate");
            require(data.stakeBlock + govContract.get("xyStakeCooldown") < block.number, "Not ready to activate stake yet");
        }
        require(data.unstakeBlock == 0, "Cannot activate unstake");
        return data;
    }

    /**
        @dev Mark stake as cooled down or activated
        cooled down stake is for non-block producers only
        @param stakingId - the tokenId of the staking token
    */
    function cooldownStake(bytes32 stakingId) 
        public
    {
        _activateStake(stakingId, true);
    }

    function activateStake(bytes32 stakingId) 
        public 
    {
        _activateStake(stakingId, false);
    }

    /**
        @dev Activate stake on a block producer
        @param stakingId - the tokenId of the staking token
    */
    function _activateStake(bytes32 stakingId, bool cooldown) 
        whenActive
        private 
    {
        Stake storage data = _requireStakeCooledDown(stakingId);
        require(data.isCooledDown == false && data.isActivated == false, "cannot re-activate stake");
        require(blockProducerContract.exists(data.stakee) != cooldown, "Only BPs activated");
        data.isCooledDown = cooldown;
        data.isActivated = !cooldown;
        updateCacheOnActivate(data);
        emit StakeEvent(stakingId, data.amount, msg.sender, data.stakee, cooldown ? StakeTransition.COOLED : StakeTransition.ACTIVATED);
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
        require(bondedStake[stakingId] == 0, "Only unstake bonded-stake via bond contract");
        require(data.staker == msg.sender, "Only the staker can unstake a stake");
        require(data.stakeBlock.add(govContract.get("xyStakeCooldown")) < block.number, "Staking needs to cooldown");
        require(data.unstakeBlock == 0, "Cannot re-unstake");
        updateCacheOnUnstake(data);
        emit StakeEvent(stakingId, data.amount, data.staker, data.stakee, StakeTransition.UNSTAKED);
    }

    /**
        Unstakes/withdraws to bonded stake
        @param bondId - the bond id to ensure the correct stake
        @param stakingId - the id of the stake to withdraw to bond contract
    */
    function unstakeBonded(bytes32 bondId, bytes32 stakingId) external {
        address bondContract = address(govContract.get('XyBondContract'));
        require(msg.sender == bondContract, "only from bond contract");
        require(bondId == bondedStake[stakingId], "Stake not bonded to this bond");
        Stake storage data = stakeData[stakingId];
        if (data.unstakeBlock==0) {
            updateCacheOnUnstake(data);
            emit StakeEvent(stakingId, data.amount, data.staker, data.stakee, StakeTransition.UNSTAKED);
        }
        _withdrawStakeData(stakingId, data);
        delete bondedStake[stakingId];
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
        Internally used to remove and adjust state array with no iterating 
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

    function _withdrawStakeData(bytes32 stakingId, Stake storage data) private {
        updateCacheOnWithdraw(data);
        SafeERC20.transfer(xyoToken, msg.sender, data.amount);
        emit StakeEvent(stakingId, data.amount, data.staker, data.stakee, StakeTransition.WITHDREW);
        removeStakeeData(stakingId);
        removeStakerData(stakingId);
        delete stakeData[stakingId];
    }

    /** 
        Withdraw a single stake by stakingId, removes stake
        @param stakingId - the id of the stake to remove
    */
    function withdrawStake(bytes32 stakingId)
      whenActive
      public 
    {
        Stake storage data = stakeData[stakingId];
        require(bondedStake[stakingId] == 0, "Cannot withdraw bonded stake");
        require(govContract.hasUnresolvedAction(data.stakee) == false, "All actions on stakee must be resolved");
        require(data.unstakeBlock > 0 && (data.unstakeBlock + govContract.get("xyUnstakeCooldown")) < block.number, "Not ready for withdraw");
        require(data.staker == msg.sender, "Only owner can withdraw");
        _withdrawStakeData(stakingId, data);
    }

    /** 
        Withdraw a batch of passed stake
        @param stakingIds - Ids to withdraw
    */
    function withdrawManyStake(bytes32[] memory stakingIds)
        whenActive
        public
    {
        for (uint i = 0; i < stakingIds.length; i++) {
            withdrawStake(stakingIds[i]);  
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