pragma solidity >=0.5.0 <0.6.0;
import "../XyBlockProducer.sol";

contract XyBlockProducerMock is XyBlockProducer {
  address[] public stakeeMocks; // simulated stakable tokens
  
  constructor(address[] memory stakees) 
    public
    XyBlockProducer()
  {
    for (uint i = 0; i < stakees.length; i++) {
      create(stakees[i]);
    }
  }
}