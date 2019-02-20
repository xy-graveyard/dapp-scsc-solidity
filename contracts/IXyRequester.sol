pragma solidity >=0.5.0 <0.6.0;

/**
    Interface must be followed in order to receive a proper response from the Consensus Contract
*/
interface IXyRequester {  
    
    // Response types for callback
    enum RequestType { DEFAULT, BOOL, UINT, WITHDRAW }

    struct IPFSRequest {
        uint requestId;
        uint weiPayment;
        uint xyoPayment;
        uint createdAt;
        uint responseAt;
        address payable beneficiary;
        address payable asker;  // contract or address to deliver response as appropriate
    }

    /**
        @dev Callback to XYO request contract by SCSC. The  answer to the passed question
        @param requestId - the hash of the request (first 2 bytes stripped)
        @param requestType Used by scsc to signal what is in the response data
        @param response Response data from scsc
    */
    function submitResponse(uint requestId, RequestType requestType, bytes calldata response) external;
}