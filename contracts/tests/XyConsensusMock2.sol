pragma solidity >=0.5.0 <0.6.0;
import "./XyConsensusMock.sol";
import "../XyPayOnDelivery.sol";

contract XyConsensusMock2 is XyConsensusMock {

    constructor(
        address[] memory stakees,
        address _token,
        address _stakableToken,
        address _governance)
        public
    XyConsensusMock(stakees, _token, _stakableToken, _governance)
    {
    }
   

    function submitResponse(
        uint ipfs, 
        uint8 requestType, 
        bytes memory responseData,
        address pOnDAddress
    ) 
        public
        payable
    {
       XyPayOnDelivery(pOnDAddress).submitResponse(ipfs,requestType,responseData);
    }
}