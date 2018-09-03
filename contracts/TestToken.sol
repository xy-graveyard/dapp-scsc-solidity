pragma solidity ^0.4.24;

import "./BasicToken.sol";


/**
 * @title TestToken token
 * @dev The decimals are only for visualization purposes.
 * All the operations are done using the smallest and indivisible token unit,
 * just as on Ethereum all the operations are done in wei.
 */
contract TestToken is BasicToken {
  string public name;
  string public symbol;
  uint8 public decimals;

  constructor(uint initialSupply) BasicToken(initialSupply) public {
  }
}
