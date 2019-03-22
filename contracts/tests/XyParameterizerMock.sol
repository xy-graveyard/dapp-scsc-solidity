pragma solidity >=0.5.0 <0.6.0;
import "../XyParameterizer.sol";

contract XyParameterizerMock is XyParameterizer {  
  constructor(
    address _governance,
    address _token,
    address _plcr,
    uint[] memory _parameters
  ) 
    public
    XyParameterizer()
  {
    init(_governance, _token, _plcr, _parameters);
  } 
}