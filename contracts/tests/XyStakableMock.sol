pragma solidity >=0.5.0 <0.6.0;
import '../XyStakableToken.sol';

contract XyStakableMock is XyStakableToken {
  constructor(uint numToMint, address beneficiary) 
    public
    XyStakableToken()
  {
    for (uint i = 0; i < numToMint; i++) {
      _mint(beneficiary, i);
    }
  }
}