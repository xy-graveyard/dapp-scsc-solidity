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

    function submitUintRequest(
    uint ipfs, 
    uint xyoTotal, 
    uint weiPayment, 
    address payable beneficiary
    ) 
      public payable 
    {
      require (requestIndex[ipfs] == 0, "Duplicate request submitted");

      uint miningGas = msg.value.sub(weiPayment);
      uint xyoPayment = xyoTotal.sub(scsc.params().get("xyXYOMiningCost"));
      
      // remainder of value is stored on this address
      scsc.submitRequest.value(miningGas)(ipfs, msg.sender, 2);
      if (xyoPayment > 0) {
        xyoToken.transferFrom(msg.sender, address(this), xyoPayment);
      }
      IPFSRequest memory q = IPFSRequest(
        ipfs, weiPayment, xyoPayment, block.number, 0, beneficiary, msg.sender
      );
      requestIndex[ipfs] = requests.length;
      requests.push(q);
    } 

    function submitResponse(uint ipfs, uint8 responseType, bytes memory responseData) public {
      if (responseType == 1) {
        super.submitResponse(ipfs, responseType, responseData);
      } else if (responseType == 2) {
        uint result;
        for (uint i = 0; i < responseData.length; i++) {
            result = result + uint(uint8(responseData[i]))*(2**(8*(responseData.length-(i+1))));
        } 
        emit UintResponse(ipfs, result);
      }
    }
}