pragma solidity >=0.5.0 <0.6.0;

import "./XyAddressStakeBasic.sol";

contract XyAddressStake is XyAddressStakeBasic {

    event Staked(
        address indexed staker,
        address indexed stakee,
        uint256 amount
    );

    event Unstaked(
        address indexed staker,
        address indexed stakee,
        uint256 index
    );

    event Withdrawl(
        address indexed staker,
        uint256 amount
    );

    constructor(
        ERC20 _token,
        uint _stakeCooldown,
        uint _unstakeCooldown
    )
        public
    {
        token = _token;
        stakeCooldown = _stakeCooldown;
        unstakeCooldown = _unstakeCooldown;
    }

    function stake(address stakee, uint amount)
        public
    {
        address staker = msg.sender;
        token.transferFrom(msg.sender, address(this), amount);
        Stake memory  stakeData = Stake(
            staker,         //staker
            stakee,         //stakee
            amount,         //amount
            block.number,   //stakeBlock
            0               //unstakeBlock
        );
        // TODO this copies the data to two locations
        stakeeStakeMap[stakee].push(stakeData);
        stakerStakeMap[staker].push(stakeData);
        emit Staked(msg.sender, stakee, amount);
    }

    /* unstake a specific previous stake */
    function unstake(address stakee, uint index)
        public
    {
        // TODO, does this need requirement that the stake cooldown has passed?
        // TODO, need to also unstake from stakerStakeMap?
        Stake storage stakeEntry = stakeeStakeMap[stakee][index];
        require(stakeEntry.staker == msg.sender, "Only the staker can unstake a stake");
        stakeEntry.unstakeBlock = block.number;
        emit Unstaked(msg.sender, stakee, index);
    }

    function pruneStakee(address stakee) 
        public
    {
        Stake[] storage stakeList = stakeeStakeMap[stakee];
        uint index = 0;
        while (index < stakeList.length) {
            if (stakeList[index].amount == 0) {
                stakeList[index] = stakeList[stakeList.length - 1];
                stakeList.length = stakeList.length - 1;
            } else {
                index++;
            }
        }
    }

    /* withdaw all available tokens (cooled-down unstakes) for the caller account */
    function withdraw()
        public
    {
        Stake[] storage stakeList = stakerStakeMap[msg.sender];
        uint unstakeTotal = 0;
        uint index = 0;
        while (index < stakeList.length) {
            if (stakeList[index].unstakeBlock > 0 && (stakeList[index].unstakeBlock + unstakeCooldown) < block.number) {
                //set the stake to zero and remove
                unstakeTotal += stakeList[index].amount;
                stakeList[index].amount = 0;
                pruneStakee(stakeList[index].stakee);
                stakeList[index] = stakeList[stakeList.length - 1];
                stakeList.length = stakeList.length - 1;
            } else {
                index++;
            }
        }

        token.transfer(msg.sender, unstakeTotal);
        emit Withdrawl(msg.sender, unstakeTotal);
    }

    // TODO remove: public variables autogenerate getters (not setters)
    function getStakeCooldown()
        public
        view
        returns(uint)
    {
        return stakeCooldown;
    }

    function getUnstakeCooldown()
        public
        view
        returns(uint)
    {
        return unstakeCooldown;
    }

    function getToken()
        public
        view
        returns(ERC20)
    {
        return token;
    }

    /* Get the current stake, counting only stakes that have not been unstaked */    
    function getTotalStakeeStake(address stakee)
        public
        view
        returns(uint)
    {
        Stake[] storage stakeList = stakeeStakeMap[stakee];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            if (stakeList[i].unstakeBlock == 0) {
                stakeTotal += stakeList[i].amount;
            }
        }
        return stakeTotal;
    }

    /* Get the current stake, counting only stakes that have not been unstaked, is past the cooldown */    
    function getActiveStakeeStake(address stakee)
        public
        view
        returns(uint)
    {
        Stake[] storage stakeList = stakeeStakeMap[stakee];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            if (stakeList[i].unstakeBlock == 0 && (stakeList[i].stakeBlock + stakeCooldown) < block.number) {
                stakeTotal += stakeList[i].amount;
            }
        }
        return stakeTotal;
    }

    /* Get the current stake, counting only stakes that have not been unstaked */    
    function getTotalStakerStake(address staker)
        public
        view
        returns(uint)
    {
        Stake[] storage stakeList = stakerStakeMap[staker];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            if (stakeList[i].unstakeBlock == 0) {
                stakeTotal += stakeList[i].amount;
            }
        }
        return stakeTotal;
    }

    /* Get the current stake, counting only stakes that have not been unstaked, is past the cooldown */    
    function getActiveStakerStake(address staker)
        public
        view
        returns(uint)
    {
        Stake[] storage stakeList = stakerStakeMap[staker];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            if (stakeList[i].unstakeBlock == 0 && (stakeList[i].stakeBlock + stakeCooldown) < block.number) {
                stakeTotal += stakeList[i].amount;
            }
        }
        return stakeTotal;
    }

    /* Get the current unstake, counting only stakes that have been unstaked */    
    function getTotalStakerUnstake(address staker)
        public
        view
        returns(uint)
    {
        Stake[] storage stakeList = stakerStakeMap[staker];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            if (stakeList[i].unstakeBlock > 0) {
                stakeTotal += stakeList[i].amount;
            }
        }
        return stakeTotal;
    }

    /* Get the available unstake, counting only stakes that can be withdrawn */    
    function getAvailableStakerUnstake(address staker)
        public
        view
        returns(uint)
    {
        Stake[] storage stakeList = stakerStakeMap[staker];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            if (stakeList[i].unstakeBlock > 0 && (stakeList[i].unstakeBlock + unstakeCooldown) < block.number) {
                stakeTotal += stakeList[i].amount;
            }
        }
        return stakeTotal;
    }

    /* Get the current unstake, counting only stakes that have been unstaked */    
    function getTotalStakeeUnstake(address stakee)
        public
        view
        returns(uint)
    {
        Stake[] storage stakeList = stakeeStakeMap[stakee];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            if (stakeList[i].unstakeBlock > 0) {
                stakeTotal += stakeList[i].amount;
            }
        }
        return stakeTotal;
    }

    /* Get the available unstake, counting only stakes that can be withdrawn */    
    function getAvailableStakeeUnstake(address stakee)
        public
        view
        returns(uint)
    {
        Stake[] storage stakeList = stakeeStakeMap[stakee];
        uint stakeTotal = 0;
        for (uint i = 0; i < stakeList.length; i++) {
            if (stakeList[i].unstakeBlock > 0 && (stakeList[i].unstakeBlock + unstakeCooldown) < block.number) {
                stakeTotal += stakeList[i].amount;
            }
        }
        return stakeTotal;
    }
}