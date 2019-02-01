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

    function submitStringRequest(
    uint ipfs, 
    uint xyoTotal, 
    uint weiOnDelivery, 
    address payable beneficiary
    ) 
      public payable 
    {
      require (requestIndex[ipfs] == 0, "Duplicate request submitted");

      uint miningGas = msg.value.sub(weiOnDelivery);
      uint xyoOnDelivery = xyoTotal.sub(scsc.params().get("xyXYOMiningCost"));
      
      // remainder of value is stored on this address
      scsc.submitRequest.value(miningGas)(ipfs, msg.sender, 2);
      if (xyoOnDelivery > 0) {
        xyoToken.transferFrom(msg.sender, address(this), xyoOnDelivery);
      }
      IPFSRequest memory q = IPFSRequest(
        ipfs, weiOnDelivery, xyoOnDelivery, block.number, 0, beneficiary, msg.sender
      );
      requestIndex[ipfs] = requests.length;
      requests.push(q);
    } 

    function submitResponse(uint ipfs, uint8 responseType, bytes memory responseData) public {
      // if (responseType == 1) {
      //   return submitResponse(ipfs, responseType, responseData);
      // } else if (responseType == 2) {
      //   require (msg.sender == address(scsc), "only scsc can complete requests");
      //   emit UintResponse(ipfs, string(responseData));
      // }
        uint result;
        for (uint i = 0; i < responseData.length; i++) {
            result = result + uint(uint8(responseData[i]))*(2**(8*(responseData.length-(i+1))));
        } 
        emit UintResponse(ipfs, result);

    }
}