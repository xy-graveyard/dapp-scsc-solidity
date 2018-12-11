pragma solidity >=0.5.0 <0.6.0;

import "./ERC20.sol";

contract XyAddressStakeBasic {

    struct Stake {
        address staker;
        address stakee;
        uint amount;
        uint stakeBlock;
        uint unstakeBlock;
    }

    mapping (address => Stake[]) public stakeeStakeMap;
    mapping (address => Stake[]) public stakerStakeMap;

    ERC20 token;
    uint stakeCooldown;
    uint unstakeCooldown;
}