pragma solidity >=0.5.0 <0.6.0;
import "../XyPayOnDelivery.sol";

contract XyPayOnDeliveryMock is XyPayOnDelivery {
    event UintResponse(bytes32 requestId, uint response);

    constructor(
        address _scsc,
        address _xyo
    )
        public
    // XyPayOnDelivery(_scsc, _xyo)
    XyPayOnDelivery()
    {
      initialize(_scsc,_xyo);
    }

    // A sample for a uint style request
    function submitUintRequest(
    bytes32 requestId, 
    uint xyoBounty, 
    uint xyoPayOnDelivery, 
    uint weiPayOnDelivery, 
    address payable beneficiary
    ) 
      public payable 
    {
      require (requestIndex[requestId] == 0, "Duplicate request submitted");
      // remainder of value is stored on this address
      scsc.submitRequest.value(msg.value.sub(weiPayOnDelivery))(requestId, xyoBounty, msg.sender, uint8(IXyRequester.RequestType.UINT_CALLBACK));
      if (xyoPayOnDelivery > 0) {
        SafeERC20.transferFrom(xyoToken, msg.sender, address(this), xyoPayOnDelivery);
      }
      IPFSRequest memory q = IPFSRequest(
        requestId, weiPayOnDelivery, xyoPayOnDelivery, block.number, 0, beneficiary, msg.sender
      );
      requestIndex[requestId] = requests.length;
      requests.push(q);
    } 

    function submitResponse(bytes32 requestId, uint8 requestType, bytes memory responseData) public {
      if (requestType == uint8(IXyRequester.RequestType.BOOL_CALLBACK)) {
        super.submitResponse(requestId, uint8(requestType), responseData);
      } else if (requestType == uint8(IXyRequester.RequestType.UINT_CALLBACK)) {
        uint result;
        for (uint i = 0; i < responseData.length; i++) {
            result = result + uint(uint8(responseData[i]))*(2**(8*(responseData.length-(i+1))));
        } 
        emit UintResponse(requestId, result);
      }
    }
}