pragma solidity >=0.5.0 <0.6.0;

import "./token/ERC721/ERC721Enumerable.sol";
import "./token/ERC721/ERC721.sol";
import "./ownership/Ownable.sol";
import "./SafeMath.sol";
import "./XyERC20Token.sol";

contract XyStakingToken is ERC721Enumerable, Ownable {
    using SafeMath for uint;

    // 721 contract that we reference for all things staked
    ERC721 stakableToken;

    // ERC20 contract for stake denomination
    XyERC20Token token;

    // Number of cooldown blocks to allow time to challenge staked false answers
    uint public stakeCooldown;
    uint public unstakeCooldown;

    // Total/Active amounts staked by stakee and staker 
    struct StakeAmounts {
        uint totalStake;
        uint activeStake;
        uint totalUnstake;
    }
    mapping (uint => StakeAmounts) public stakeeStake;
    mapping (address => StakeAmounts) public stakerStake;

    // Stake data associated with all staking tokens
    struct Stake {
        uint amount;
        uint stakeBlock;
        uint unstakeBlock;
        uint stakee; 
        bool isActivated;
    }
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

    /** Creates a Staking token contract 
    @param _token - The token to stake with
    @param _stakableToken - The token to place stakes on
    @param _stakeCooldown - Number of blocks before a stake can be activated
    @param _unstakeCooldown - Number of blocks before a unstaked stake can be activated for withdraw
    */
    constructor (
        XyERC20Token _token,
        ERC721 _stakableToken,
        uint _stakeCooldown,
        uint _unstakeCooldown
    )
        public
    {
        token = _token;
        stakableToken = _stakableToken;
        stakeCooldown = _stakeCooldown;
        unstakeCooldown = _unstakeCooldown;
    }

    /** Increase and decrease cached stake amounts */
    function updateCacheOnStake(uint amount, uint stakee) internal {
        stakeeStake[stakee].totalStake = stakeeStake[stakee].totalStake.add(amount);
        stakerStake[msg.sender].totalStake = stakerStake[msg.sender].totalStake.add(amount);
    }
    function updateCacheOnActivate(uint amount, uint stakee) internal {
        stakeeStake[stakee].activeStake = stakeeStake[stakee].activeStake.add(amount);
        stakerStake[msg.sender].activeStake = stakerStake[msg.sender].activeStake.add(amount);
    }
    function updateCacheOnUnstake(Stake memory data) internal {
        stakeeStake[data.stakee].totalStake = stakeeStake[data.stakee].totalStake.sub(data.amount);
        stakerStake[msg.sender].totalStake = stakerStake[msg.sender].totalStake.sub(data.amount);
        if (data.isActivated) {
            stakeeStake[data.stakee].activeStake = stakeeStake[data.stakee].activeStake.sub(data.amount);
            stakerStake[msg.sender].activeStake = stakerStake[msg.sender].activeStake.sub(data.amount);
        }
        stakeeStake[data.stakee].totalUnstake = stakeeStake[data.stakee].totalUnstake.add(data.amount);
        stakerStake[msg.sender].totalUnstake = stakerStake[msg.sender].totalUnstake.add(data.amount);
    }
    function updateCacheOnWithdraw(uint amount, uint stakee) internal {
        stakeeStake[stakee].totalUnstake = stakeeStake[stakee].totalUnstake.sub(amount);
        stakerStake[msg.sender].totalUnstake = stakerStake[msg.sender].totalUnstake.sub(amount);
    }

    /** 
        Adds stake to a stakable token id
        @dev This contract must be approved to transfer tokens by token holder
        @param stakee - the stakable token to stake
        @param amount - the amount to stake
    */
    function stake(uint stakee, uint amount)
        public
        returns (uint)
    {
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
        token.transferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, newToken, stakee, amount);
        return newToken;
    }
    
    /**
        @dev Activate a stake that is past challenge period within XYO
        @param stakingToken - the tokenId of the staking token
     */
    function activateStake(uint stakingToken) public {
        require (ownerOf(stakingToken) == msg.sender, "Only the staker can activate");
        Stake storage data = stakeData[stakingToken];
        require(data.isActivated == false, "cannot re-activate stake");
        data.isActivated = true;
        require(data.stakeBlock + stakeCooldown < block.number, "Not ready to activate stake yet");
        updateCacheOnActivate(data.amount, data.stakee);
        emit ActivatedStake(msg.sender, stakingToken, data.stakee, data.amount);
    }

    /** 
        unstake a specific previous stake 
        @param stakingToken - the tokenId of the staking token
    */
    function unstake(uint stakingToken)
        public
    {
        require (ownerOf(stakingToken) == msg.sender, "Only the staker can unstake a stake");
        Stake storage data = stakeData[stakingToken];
        require(data.stakeBlock + stakeCooldown < block.number, "Staking needs to cooldown");
        require(data.unstakeBlock == 0, "Cannot re-unstake");
        updateCacheOnUnstake(data);
        data.unstakeBlock = block.number;
        emit Unstaked(msg.sender, stakingToken, data.stakee, data.amount);
    }

    /** 
        Internally used to burn token and adjust state array with no iterating 
        @param stakee - the stakable token associated with staking token
        @param stakingToken - the tokenId of the staking token to burn
    */
    function burn(uint stakee, uint stakingToken) internal {
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
      public 
    {
        require(_isApprovedOrOwner(msg.sender, stakingToken), "Only approved or owner can withdraw");
        Stake memory data = stakeData[stakingToken];
        require (data.unstakeBlock > 0 && (data.unstakeBlock + unstakeCooldown) < block.number, "Not ready for withdraw");
        burn(data.stakee, stakingToken);
        token.transfer(msg.sender, data.amount);
        updateCacheOnWithdraw(data.amount, data.stakee);
        emit Withdrawl(msg.sender, data.amount);
    }

    /** 
        Withdraw a batch of first avaliable staking tokens
        @param batchLimit - Allows iterating over withdrawing due to gas limits
        if batchlimit is 0, try withdrawing all available tokens (be prepared for out of gas if you've got > 50 tokens)
    */
    function withdrawMany(uint batchLimit)
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
            if (data.unstakeBlock > 0 && (data.unstakeBlock + unstakeCooldown) < block.number) {
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
            token.transfer(msg.sender, withdrawAmt);
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
            if (data.unstakeBlock > 0 && (data.unstakeBlock + unstakeCooldown) < block.number) {
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
            if (data.unstakeBlock > 0 && (data.unstakeBlock + unstakeCooldown) < block.number) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }
}