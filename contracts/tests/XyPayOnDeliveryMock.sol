pragma solidity >=0.5.0 <0.6.0;
import "../XyPayonDelivery.sol";

contract XyPayOnDeliveryMock is XyPayOnDelivery {
    event UintResponse(uint requestId, uint response);

    constructor(
        address _scsc,
        address _xyo
    )
        public
    XyPayOnDelivery()
    {
    }

    // A sample for a uint style request
    function submitUintRequest(
    uint requestId, 
    uint xyoBounty, 
    uint xyoPayOnDelivery, 
    uint weiPayOnDelivery, 
    address payable beneficiary
    ) 
      public payable 
    {
      require (requestIndex[requestId] == 0, "Duplicate request submitted");
      // remainder of value is stored on this address
      scsc.submitRequest.value(msg.value.sub(weiPayOnDelivery))(requestId, xyoBounty, msg.sender, IXyRequester.RequestType.UINT);
      if (xyoPayOnDelivery > 0) {
        xyoToken.transferFrom(msg.sender, address(this), xyoPayOnDelivery);
      }
      IPFSRequest memory q = IPFSRequest(
        requestId, weiPayOnDelivery, xyoPayOnDelivery, block.number, 0, beneficiary, msg.sender
      );
      requestIndex[requestId] = requests.length;
      requests.push(q);
    } 

    function submitResponse(uint requestId, IXyRequester.RequestType requestType, bytes memory responseData) public {
      if (requestType == IXyRequester.RequestType.BOOL) {
        super.submitResponse(requestId, requestType, responseData);
      } else if (requestType == IXyRequester.RequestType.UINT) {
        uint result;
        for (uint i = 0; i < responseData.length; i++) {
            result = result + uint(uint8(responseData[i]))*(2**(8*(responseData.length-(i+1))));
        } 
        emit UintResponse(requestId, result);
      }
    }
}