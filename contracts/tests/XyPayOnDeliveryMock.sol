pragma solidity >=0.5.0 <0.6.0;
import "../XyPayonDelivery.sol";

contract XyPayOnDeliveryMock is XyPayOnDelivery {
    event UintResponse(uint ipfs, uint response);

    constructor(
        address _scsc,
        address _xyo
    )
        public
    XyPayOnDelivery(_scsc, _xyo)
    {
    }

    // A sample for a uint style request
    function submitUintRequest(
    uint ipfs, 
    uint xyoBounty, 
    uint xyoPayOnDelivery, 
    uint weiPayOnDelivery, 
    address payable beneficiary
    ) 
      public payable 
    {
      require (requestIndex[ipfs] == 0, "Duplicate request submitted");
      // remainder of value is stored on this address
      scsc.submitRequest.value(msg.value.sub(weiPayOnDelivery))(ipfs, xyoBounty, msg.sender, 2);
      if (xyoPayOnDelivery > 0) {
        xyoToken.transferFrom(msg.sender, address(this), xyoPayOnDelivery);
      }
      IPFSRequest memory q = IPFSRequest(
        ipfs, weiPayOnDelivery, xyoPayOnDelivery, block.number, 0, beneficiary, msg.sender
      );
      requestIndex[ipfs] = requests.length;
      requests.push(q);
    } 

    function submitResponse(uint ipfs, uint8 requestType, bytes memory responseData) public {
      if (requestType == 1) {
        super.submitResponse(ipfs, requestType, responseData);
      } else if (requestType == 2) {
        uint result;
        for (uint i = 0; i < responseData.length; i++) {
            result = result + uint(uint8(responseData[i]))*(2**(8*(responseData.length-(i+1))));
        } 
        emit UintResponse(ipfs, result);
      }
    }
}