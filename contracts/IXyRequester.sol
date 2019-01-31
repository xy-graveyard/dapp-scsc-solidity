pragma solidity >=0.5.0 <0.6.0;

  
interface IXyRequester {
    struct IPFSRequest {
        uint ipfs;
        uint weiOnDelivery;
        uint xyoOnDelivery;
        uint createdAt;
        uint responseAt;
        address payable beneficiary;
        address payable asker;
    }

    function submitResponse(uint question, uint8 responseType, bytes calldata response) external;
}