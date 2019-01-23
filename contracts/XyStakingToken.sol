pragma solidity >=0.5.0 <0.6.0;

import "./token/ERC721/ERC721.sol";
import "./token/ERC721/ERC721Enumerable.sol";
import "./SafeMath.sol";
import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./token/ERC20/XyERC20Token.sol";
import "./XyGovernance.sol";
import "./token/ERC20/SafeERC20.sol";

contract XyStakingToken is ERC721Enumerable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    // IERC20 contract for stake denomination
    IERC20 xyoToken;

    // 721 contract that we reference for all things staked
    ERC721 stakableToken;

    XyGovernance public params;

    // Number of cooldown blocks to allow time to challenge staked false answers
    uint public stakeCooldown;
    uint public unstakeCooldown;

    // Track the total active stake in XYO
    uint public totalActiveStake;

    // Stake data associated with all staking tokens
    struct Stake {
        uint amount;
        uint stakeBlock;
        uint unstakeBlock;
        uint stakee; 
        bool isActivated;
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier whenActive() {
        require(params.get("xyPaused") == 0, "Staking is Paused");
        _;
    }

    // Mapping from token id to stake metadata     
    mapping (uint => Stake) public stakeData;

    // The staking token ids associated with stakable tokens
    mapping (uint => uint[]) public stakeeStakingTokenMap;

    // holds the Staking token index in the stakeeStakingTokenMap array
    mapping (uint => uint) public stakingTokenStakeeIndex;
    
    /** EVENTS */
    event Staked(
        address indexed staker,
        uint indexed stakingToken,
        uint indexed stakee,
        uint amount
    );

    event ActivatedStake(
        address indexed staker,
        uint indexed stakingToken,
        uint indexed stakee,
        uint amount
    );

    event Unstaked(
        address indexed staker,
        uint indexed stakingToken,
        uint indexed stakee,
        uint amount
    );

    event Withdrawl(
        address indexed staker,
        uint amount
    );

    // Total/Active amounts staked by stakee and staker 
    struct StakeAmounts {
        uint totalStake;
        uint activeStake;
        uint totalUnstake;
    }

    mapping (uint => StakeAmounts) public stakeeStake;
    mapping (address => StakeAmounts) public stakerStake;

    /** Creates a Staking token contract 
    @param _token - The token to stake with
    @param _stakableToken - The token to place stakes on
    */
    constructor (
        address _token,
        address _stakableToken,
        address _governanceContract
    )
        public
    {
        xyoToken = IERC20(_token);
        stakableToken = ERC721(_stakableToken);
        params = XyGovernance(_governanceContract);
    }

    /** Increase and decrease cached stake amounts */
    function updateCacheOnStake(uint amount, uint stakee) internal {
        stakeeStake[stakee].totalStake = stakeeStake[stakee].totalStake.add(amount);
        stakerStake[msg.sender].totalStake = stakerStake[msg.sender].totalStake.add(amount);
    }
    function updateCacheOnActivate(uint amount, uint stakee) internal {
        stakeeStake[stakee].activeStake = stakeeStake[stakee].activeStake.add(amount);
        stakerStake[msg.sender].activeStake = stakerStake[msg.sender].activeStake.add(amount);
        totalActiveStake = totalActiveStake.add(amount);
    }
    function updateCacheOnUnstake(Stake memory data, address from) internal {
        stakeeStake[data.stakee].totalStake = stakeeStake[data.stakee].totalStake.sub(data.amount);
        stakerStake[from].totalStake = stakerStake[from].totalStake.sub(data.amount);
        if (data.isActivated) {
            stakeeStake[data.stakee].activeStake = stakeeStake[data.stakee].activeStake.sub(data.amount);
            stakerStake[from].activeStake = stakerStake[from].activeStake.sub(data.amount);
            totalActiveStake = totalActiveStake.sub(data.amount);
        }
        stakeeStake[data.stakee].totalUnstake = stakeeStake[data.stakee].totalUnstake.add(data.amount);
        stakerStake[from].totalUnstake = stakerStake[from].totalUnstake.add(data.amount);
    }
    function updateCacheOnWithdraw(uint amount, uint stakee) internal {
        stakeeStake[stakee].totalUnstake = stakeeStake[stakee].totalUnstake.sub(amount);
        stakerStake[msg.sender].totalUnstake = stakerStake[msg.sender].totalUnstake.sub(amount);
    }

    function _unstakeGovernanceAction(uint stakee, uint startIndex, uint batchSize) private {
        for (uint i = startIndex; i < batchSize + startIndex; i++) {
            uint token = stakeeStakingTokenMap[stakee][i];
            Stake storage data = stakeData[token];
            if (data.unstakeBlock == 0) {
                updateCacheOnUnstake(data, ownerOf(token));
                data.unstakeBlock = block.number;
            }
        }
        if (stakeeStake[stakee].activeStake == 0) {
            params.resolveAction(stakee);
        }
    }

    function resolveGovernanceAction(uint stakee, uint startIndex, uint batchSize) public {
        (,,,uint8 actionType, bool accepted) = params.actions(stakee);
        require(accepted == true, "action must be accepted");
        // unstake action
        if (actionType == 1) {
            _unstakeGovernanceAction(stakee, startIndex, batchSize);
        }
        // TODO more governance actions?
    }

    /** 
        Adds stake to a stakable token id
        @dev This contract must be approved to transfer tokens by token holder
        @param stakee - the stakable token to stake
        @param amount - the amount to stake
    */
    function stake(uint stakee, uint amount)
        whenActive 
        public
        returns (uint)
    {
        require(params.hasUnresolvedAction(stakee) == false, "All actions on stakee must be resolved");
        require(stakableToken.ownerOf(stakee) != address(0), "Stakable token must exist");
        updateCacheOnStake(amount, stakee);

        // random generated token id
        uint newToken = uint(keccak256(abi.encodePacked(stakee, msg.sender, block.number)));
        _mint(msg.sender, newToken);

        Stake memory data = Stake(
            amount,         // amount
            block.number,   // stakeBlock
            0,              // unstakeBlock
            stakee,         // stakee 
            false           // isActivated
        );

        // // Store the staking data
        stakingTokenStakeeIndex[newToken] = stakeeStakingTokenMap[stakee].length;
        stakeeStakingTokenMap[stakee].push(newToken);
        stakeData[newToken] = data;

        // Escrow the ERC20
        // xyoToken.asmTransferFrom(msg.sender, address(this), amount);
        xyoToken.transferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, newToken, stakee, amount);
        return newToken;
    }
    
    /**
        @dev Activate a stake that is past challenge period within XYO
        @param stakingToken - the tokenId of the staking token
     */
    function activateStake(uint stakingToken) 
        whenActive
        public 
    {
        require (ownerOf(stakingToken) == msg.sender, "Only the staker can activate");
        Stake storage data = stakeData[stakingToken];
        require(data.isActivated == false, "cannot re-activate stake");
        data.isActivated = true;
        require(data.stakeBlock + params.get("xyStakeCooldown") < block.number, "Not ready to activate stake yet");
        updateCacheOnActivate(data.amount, data.stakee);
        emit ActivatedStake(msg.sender, stakingToken, data.stakee, data.amount);
    }

    /** 
        unstake a specific previous stake 
        @param stakingToken - the tokenId of the staking token
    */
    function unstake(uint stakingToken)
        whenActive
        public
    {
        require (ownerOf(stakingToken) == msg.sender, "Only the staker can unstake a stake");
        Stake storage data = stakeData[stakingToken];
        require(data.stakeBlock + params.get("xyStakeCooldown") < block.number, "Staking needs to cooldown");
        require(data.unstakeBlock == 0, "Cannot re-unstake");
        updateCacheOnUnstake(data, msg.sender);
        data.unstakeBlock = block.number;
        emit Unstaked(msg.sender, stakingToken, data.stakee, data.amount);
    }

    /** 
        Internally used to burn token and adjust state array with no iterating 
        @param stakee - the stakable token associated with staking token
        @param stakingToken - the tokenId of the staking token to burn
    */
    function burn(uint stakee, uint stakingToken) 
        internal 
    {
      uint index = stakingTokenStakeeIndex[stakingToken];
      uint lastIndex = stakeeStakingTokenMap[stakee].length.sub(1);
      uint lastToken = stakeeStakingTokenMap[stakee][lastIndex];
        
      stakeeStakingTokenMap[stakee][index] = lastToken;
      stakeeStakingTokenMap[stakee][lastIndex] = 0;

      stakeeStakingTokenMap[stakee].length--;
      delete stakingTokenStakeeIndex[stakingToken];
      stakingTokenStakeeIndex[lastToken] = index;

      _burn(ownerOf(stakingToken), stakingToken);
    }

    /** 
        Withdraw a single token's stake by token id, burns staking token
        @param stakingToken - the tokenId of the staking token to burn
    */
    function withdraw(uint stakingToken)
      whenActive
      public 
    {
        require(_isApprovedOrOwner(msg.sender, stakingToken), "Only approved or owner can withdraw");
        Stake memory data = stakeData[stakingToken];
        require (data.unstakeBlock > 0 && (data.unstakeBlock + params.get("xyUnstakeCooldown")) < block.number, "Not ready for withdraw");
        burn(data.stakee, stakingToken);
        updateCacheOnWithdraw(data.amount, data.stakee);
        xyoToken.safeTransfer(msg.sender, data.amount);
        emit Withdrawl(msg.sender, data.amount);
    }

    /** 
        Withdraw a batch of first avaliable staking tokens
        @param batchLimit - Allows iterating over withdrawing due to gas limits
        if batchlimit is 0, try withdrawing all available tokens (be prepared for out of gas if you've got > 50 tokens)
    */
    function withdrawMany(uint batchLimit)
        whenActive
        public
    {
        uint balance = balanceOf(msg.sender);
        uint limit = batchLimit > 0 ? batchLimit : balance;
        uint withdrawAmt = 0;
        uint[] memory burnTokens = new uint[](limit);
        uint numBurnTokens = 0;
        for (uint i = 0; i < balance && i < limit; i++) {
            uint tokenId = tokenOfOwnerByIndex(msg.sender, i);
            Stake memory data = stakeData[tokenId];
            if (data.unstakeBlock > 0 && (data.unstakeBlock + params.get("xyUnstakeCooldown")) < block.number) {
                burnTokens[numBurnTokens] = tokenId;      
                numBurnTokens++;
            }      
        }
        for (uint b = 0; b < numBurnTokens; b++) {
            Stake memory data = stakeData[burnTokens[b]];
            withdrawAmt += data.amount;
            burn(data.stakee, burnTokens[b]);
            updateCacheOnWithdraw(data.amount, data.stakee);
        }

        if (withdrawAmt > 0) {
            xyoToken.safeTransfer(msg.sender, withdrawAmt);
            emit Withdrawl(msg.sender, withdrawAmt);
        }
    }

    /** Get the available unstake, counting only stakes that can be withdrawn */    
    function getAvailableStakerUnstake(address staker)
        external
        view
        returns(uint)
    {
        uint stakeTotal = 0;
        uint balance = balanceOf(staker);
        for (uint i = 0; i < balance; i++) {
            Stake memory data = stakeData[tokenOfOwnerByIndex(staker, i)];
            if (data.unstakeBlock > 0 && (data.unstakeBlock + params.get("xyUnstakeCooldown")) < block.number) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }

    /** Get the available unstake, counting only stakes that can be withdrawn */    
    function getAvailableStakeeUnstake(uint stakee)
        external
        view
        returns(uint)
    {
        uint[] memory stakeList = stakeeStakingTokenMap[stakee];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            Stake memory data = stakeData[stakeList[i]];
            if (data.unstakeBlock > 0 && (data.unstakeBlock + params.get("xyUnstakeCooldown")) < block.number) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }
}