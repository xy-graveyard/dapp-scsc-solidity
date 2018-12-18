pragma solidity >=0.5.0 <0.6.0;

import "./token/ERC721/ERC721Enumerable.sol";
import "./token/ERC721/ERC721.sol";
import "./ownership/Ownable.sol";
import "./SafeMath.sol";
import "./ERC20.sol";

contract XyStakingToken is ERC721Enumerable, Ownable {
    using SafeMath for uint;

    // 721 contract that we reference for all things staked
    ERC721 stakableToken;

    // ERC20 contract for stake denomination
    ERC20 token;

    // Number of cooldown blocks to allow time to challenge staked false answers
    uint public stakeCooldown;
    uint public unstakeCooldown;

    // Total/Active amounts staked by stakee and staker 
    struct StakerStake {
        uint totalStake;
        uint activeStake;
        uint totalUnstake;
        uint activeUnstake;
    }
    struct StakeeStake {
        uint totalStake;
        uint activeStake;
        uint totalUnstake;
        uint activeUnstake;
    }
    mapping (uint => StakeeStake) stakeeStake;
    mapping (address => StakerStake) stakerStake;

    // Stake data associated with all staking tokens
    struct Stake {
        uint amount;
        uint stakeBlock;
        uint unstakeBlock;
        uint stakee; 
        bool activatedStake;
        bool activatedUnstake;
    }
    mapping (uint => Stake) stakeData;

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

    event ActivatedUnstake(
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
        ERC20 _token,
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
    function updateCacheOnStake(uint amount, uint stakee) private {
        stakeeStake[stakee].totalStake = stakeeStake[stakee].totalStake.add(amount);
        stakerStake[msg.sender].totalStake = stakerStake[msg.sender].totalStake.add(amount);
    }
    function updateCacheOnActivate(uint amount, uint stakee) private {
        stakeeStake[stakee].activeStake = stakeeStake[stakee].activeStake.add(amount);
        stakerStake[msg.sender].activeStake = stakerStake[msg.sender].activeStake.add(amount);
    }
    function updateCacheOnUnstake(uint amount, uint stakee) private {
        stakeeStake[stakee].totalStake = stakeeStake[stakee].totalStake.sub(amount);
        stakerStake[msg.sender].totalStake = stakerStake[msg.sender].totalStake.sub(amount);
        stakeeStake[stakee].activeStake = stakeeStake[stakee].activeStake.sub(amount);
        stakerStake[msg.sender].activeStake = stakerStake[msg.sender].activeStake.sub(amount);

        stakeeStake[stakee].totalUnstake = stakeeStake[stakee].totalUnstake.add(amount);
        stakerStake[msg.sender].totalUnstake = stakerStake[msg.sender].totalUnstake.add(amount);
    }
    function updateCacheOnActivateUnstake(uint amount, uint stakee) private {
        stakeeStake[stakee].activeUnstake = stakeeStake[stakee].activeUnstake.add(amount);
        stakerStake[msg.sender].activeUnstake = stakerStake[msg.sender].activeUnstake.add(amount);
    }
    function updateCacheOnWithdraw(uint amount, uint stakee) private {
        stakeeStake[stakee].totalUnstake = stakeeStake[stakee].totalUnstake.sub(amount);
        stakerStake[msg.sender].totalUnstake = stakerStake[msg.sender].totalUnstake.sub(amount);
        stakeeStake[stakee].activeUnstake = stakeeStake[stakee].activeUnstake.sub(amount);
        stakerStake[msg.sender].activeUnstake = stakerStake[msg.sender].activeUnstake.sub(amount);
    }

    /**
        @dev Activate a stake that is past challenge period within XYO
        @param stakingToken - the tokenId of the staking token
     */
    function activateStake(uint stakingToken) public {
        require (ownerOf(stakingToken) == msg.sender, "Only the staker can activate");
        Stake memory data = stakeData[stakingToken];
        require(data.activatedStake == false, "cannot re-activate stake");
        data.activatedStake = true;
        require(data.stakeBlock + stakeCooldown < block.number, "Not ready to activate stake yet");
        updateCacheOnActivate(data.amount, data.stakee);
        emit ActivatedStake(msg.sender, stakingToken, data.stakee, data.amount);
    }

    /**
        @dev Activate an unstake needs to be done to ensure after unstake challenge period
        @param stakingToken - the tokenId of the staking token
     */
    function activateUnstake(uint stakingToken) public {
        require (ownerOf(stakingToken) == msg.sender, "Only the staker can activate unstake");
        Stake memory data = stakeData[stakingToken];
        require(data.activatedUnstake == false, "cannot re-activate unstake");
        data.activatedUnstake = true;
        require(data.stakeBlock + stakeCooldown < block.number, "Not ready to activate unstake yet");
        updateCacheOnActivateUnstake(data.amount, data.stakee);
        emit ActivatedUnstake(msg.sender, stakingToken, data.stakee, data.amount);
    }

    /** 
        Adds stake to a stakable token id
        @param stakee - the stakable token to stake
        @param amount - the amount to stake
    */
    function stake(uint stakee, uint amount)
        public
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
            stakee,          // stakee 
            false,          // activated stake
            false           // activated unstake
        );

        // Store the staking data
        stakingTokenStakeeIndex[newToken] = stakeeStakingTokenMap[stakee].length;
        stakeeStakingTokenMap[stakee].push(newToken);
        stakeData[newToken] = data;

        // Escrow the ERC20
        stakableToken.transferFrom(msg.sender, address(this), amount);
        emit Unstaked(msg.sender, newToken, stakee, amount);
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

        updateCacheOnUnstake(data.amount, data.stakee);
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
    */
    function withdrawMany(uint batchLimit)
        public
    {
        uint balance = balanceOf(msg.sender);
        uint withdrawAmt = 0;
        for (uint i = 0; i < balance && i < batchLimit; i++) {
            uint tokenId = tokenOfOwnerByIndex(msg.sender, i);
            Stake memory data = stakeData[tokenId];
            if (data.unstakeBlock > 0 && (data.unstakeBlock + unstakeCooldown) < block.number) {
                withdrawAmt += data.amount;
                burn(data.stakee, tokenId);
                updateCacheOnWithdraw(withdrawAmt, data.stakee);
            }
        }

        token.transfer(msg.sender, withdrawAmt);

        emit Withdrawl(msg.sender, withdrawAmt);
    }

}