pragma solidity >=0.5.0 <0.6.0;
import "../XyStakableToken.sol";

contract XyStakableAddressMock is XyStakableToken {
  address[] public stakeeMocks; // simulated stakable tokens
  
  constructor(address beneficiary, address[] memory stakees) 
    public
    XyStakableToken(address(0))
  {
    for (uint i = 0; i < stakees.length; i++) {
      uint stakee = uint(stakees[i]);
      stakeeMocks.push(stakees[i]);
      _mint(beneficiary, stakee);
    }
  }
}