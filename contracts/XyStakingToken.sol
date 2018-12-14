pragma solidity >=0.5.0 <0.6.0;

import "./token/ERC721/ERC721Enumerable.sol";
import "./token/ERC721/ERC721.sol";
import "./XyAddressStakeBasic.sol";
import "./ownership/Ownable.sol";

contract XyStakingToken is ERC721Enumerable, Ownable {

    struct Stake {
        uint amount;
        uint stakeBlock;
        uint unstakeBlock;
        uint stakee; 
    }

    uint public stakeCooldown;
    uint public unstakeCooldown;

    // 721 contract that we reference for all things staked
    ERC721 stakableToken;
    ERC20 token;

    // Cache total stakee staked amount 
    mapping (uint => uint) totalStakeeStake;

    // Cache total staker staked amount 
    mapping (address => uint) totalStakerStake;

    // data associated with owned stake
    mapping (uint => Stake) stakeData;

    // The staking token ids associated with stakable tokens
    mapping (uint => uint[]) public stakeeStakingTokenMap;

    // holds the Staking token index in the stakeeStakingTokenMap array
    mapping (uint => uint) public stakingTokenStakeeIndex;
    
    event Staked(
        address indexed staker,
        uint indexed stakeToken,
        uint indexed stakeeToken,
        uint256 amount
    );

    event Unstaked(
        address indexed staker,
        uint indexed stakeToken
    );

    event Withdrawl(
        address indexed staker,
        uint256 amount
    );

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

    /** Increase and decrease total stakes for caching purposes */
    function increaseTotalStakeeStake(uint amount, uint stakee) private {
        totalStakeeStake[stakee] += amount;
        totalStakerStake[msg.sender] += amount;
    }
    function decreaseTotalStakeeStake(uint amount, uint stakee) private {
        totalStakeeStake[stakee] -= amount;
        totalStakerStake[msg.sender] -= amount;
    }

    /** 
        Adds stake to a stakable token id
        @param stakee - the stakable token to unstake
        @param amount - the amount to stake
    */
    function stake(uint stakee, uint amount)
        public
    {
        require(stakableToken.ownerOf(stakee) != address(0), "Stakable token must exist");
        increaseTotalStakeeStake(amount, stakee);

        // random generated token id
        uint newToken = uint(keccak256(abi.encodePacked(stakee, msg.sender, block.number)));
        _mint(msg.sender, newToken);

        Stake memory data = Stake(
            amount,         // amount
            block.number,   // stakeBlock
            0,              // unstakeBlock
            stakee          // stakee 
        );

        // Store the staking data
        stakingTokenStakeeIndex[newToken] = stakeeStakingTokenMap[stakee].length;
        stakeeStakingTokenMap[stakee].push(newToken);
        stakeData[newToken] = data;

        // Escrow the ERC20
        stakableToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, newToken, stakee, amount);
    }

    /** 
        unstake a specific previous stake 
        @param stakee - the stakable token to unstake
        @param stakingToken - the tokenId of the staking token
    */
    function unstake(uint stakee, uint stakingToken)
        public
    {
        require (ownerOf(stakingToken) == msg.sender, "Only the staker can unstake a stake");
        Stake storage data = stakeData[stakingToken];
        require(data.stakeBlock + stakeCooldown < block.number, "Staking needs to cooldown");

        decreaseTotalStakeeStake(data.amount, stakee);
        data.unstakeBlock = block.number;
        emit Unstaked(msg.sender, stakingToken);
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
      uint unstakeBlock = stakeData[stakingToken].unstakeBlock;

      require (unstakeBlock > 0 && (unstakeBlock + unstakeCooldown) < block.number, "Not ready for withdraw");
      uint stakee = stakeData[stakingToken].stakee;
      burn(stakee, stakingToken);
      token.transfer(msg.sender, stakeData[stakingToken].amount);
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
            }
        }

        token.transfer(msg.sender, withdrawAmt);
        emit Withdrawl(msg.sender, withdrawAmt);
    }

    /** Get the current stake, counting only stakes that have not been unstaked, is past the cooldown */    
    function getActiveStakerStake(address staker)
        public
        view
        returns(uint)
    {
        uint stakeTotal = 0;
        for (uint i = 0; i < balanceOf(staker); i++) {
            uint tokenId = tokenOfOwnerByIndex(msg.sender, i);
            Stake memory data = stakeData[tokenId];          
            if (data.unstakeBlock == 0 && (data.stakeBlock + stakeCooldown) < block.number) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }

    /** Get the current unstake, counting only stakes that have been unstaked */    
    function getTotalStakerUnstake(address staker)
        public
        view
        returns(uint)
    {
        uint stakeTotal = 0;
        for (uint i = 0; i < balanceOf(staker); i++) {
            Stake memory data = stakeData[tokenOfOwnerByIndex(msg.sender, i)];
            if (data.unstakeBlock > 0) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }

    /** Get the available unstake, counting only stakes that can be withdrawn */    
    function getAvailableStakerUnstake(address staker)
        public
        view
        returns(uint)
    {
        uint stakeTotal = 0;
        for (uint i = 0; i < balanceOf(staker); i++) {
            Stake memory data = stakeData[tokenOfOwnerByIndex(msg.sender, i)];
            if (data.unstakeBlock > 0 && (data.unstakeBlock + unstakeCooldown) < block.number) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }


    /** Get the current stake, counting only stakes that have not been unstaked, is past the cooldown */    
    function getActiveStakeeStake(uint stakee)
        public
        view
        returns(uint)
    {
        uint[] memory stakeList = stakeeStakingTokenMap[stakee];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            Stake memory data = stakeData[stakeList[i]];
            if (data.unstakeBlock == 0 && (data.stakeBlock + stakeCooldown) < block.number) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }

    /** Get the current unstake, counting only stakes that have been unstaked */    
    function getTotalStakeeUnstake(uint stakee)
        public
        view
        returns(uint)
    {
        uint[] memory stakeList = stakeeStakingTokenMap[stakee];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            Stake memory data = stakeData[stakeList[i]];
            if (data.unstakeBlock > 0) {
                stakeTotal += data.amount;
            }
        }
        return stakeTotal;
    }

    /** Get the available unstake, counting only stakes that can be withdrawn */    
    function getAvailableStakeeUnstake(uint stakee)
        public
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