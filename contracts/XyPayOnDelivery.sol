pragma solidity >=0.5.0 <0.6.0;

import "./SafeMath.sol";
import "./XyStakingConsensus.sol";
import "./token/ERC20/IERC20.sol";
import "./IXyRequester.sol";
import "./token/ERC20/SafeERC20.sol";


/**
 * @title A Payment on delivery contract
 * @dev Will escrow funds until an item is marked as delivered .
 */
contract XyPayOnDelivery is IXyRequester {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    XyStakingConsensus public scsc;
    IERC20 public xyoToken;

    event IntersectResponse(uint ipfs, uint weiPayment, uint xyoPayment, address payable beneficiary, bool didIntersect);

    // Check that 
    mapping (uint => bool) public didIntersect;
    mapping (uint => uint) public requestIndex;
    IPFSRequest[] public requests;

    /* 
        Construct a Pay Delivery contract
    */
    constructor (
        address stakingConsensus, 
        address _xyoToken
    )
        public 
    {
        scsc = XyStakingConsensus(stakingConsensus);
        xyoToken = IERC20(_xyoToken);
    }

    /**
        @dev Called by PonD client.  API for client to request an intersection question
        @param ipfs - the hash of the request (first 2 bytes stripped)
        @param xyoPayment - the amount of XYO to pay on delivery (should include mining gas)
        @param weiPayment - the amount of eth to pay on delivery
        @param beneficiary The destination address of the funds.
    */
    function submitPayOnDelivery(
        uint ipfs, 
        uint xyoPayment, 
        uint weiPayment, 
        address payable beneficiary
    ) 
        public 
        payable 
    {
        require (requestIndex[ipfs] == 0, "Duplicate request submitted");
        require (msg.value >= weiPayment, "Not enough payment provided");
        
        uint miningGas = msg.value.sub(weiPayment);
        scsc.submitRequest.value(miningGas)(ipfs, msg.sender, 1);
        
        if (xyoPayment > 0) {
            require (xyoToken.allowance(msg.sender, address(this)) >= xyoPayment, "must approve PonD for XYO Payment");
            xyoToken.transferFrom(msg.sender, address(this), xyoPayment);
        }

        IPFSRequest memory q = IPFSRequest(
            ipfs, weiPayment, xyoPayment, block.number, 0, beneficiary, msg.sender
        );
        requestIndex[ipfs] = requests.length;
        requests.push(q);
    }

    /**
        @dev Called by SCSC. If intersection, transfer pay on delivery to beneficiary, delete request
        @param ipfs - the hash of the request (first 2 bytes stripped)
        @param responseType Used by scsc to signal what is in the response data
        @param responseData Response data from scsc
    */
    function submitResponse(uint ipfs, uint8 responseType, bytes memory responseData) public {
        require (msg.sender == address(scsc), "only scsc can complete requests");
        bool intersection = responseData.length > 0 && responseData[0] > 0;
        didIntersect[ipfs] = intersection;
        IPFSRequest storage q = requests[requestIndex[ipfs]];
        q.responseAt = block.number;

        if (intersection) {
            payOnDelivery(ipfs, q.beneficiary);
        } else {
            payOnDelivery(ipfs, q.asker);
        }
        emit IntersectResponse(q.ipfs, q.weiPayment, q.xyoPayment, q.beneficiary, true);
    }

    /** 
        Will refund the asker prior to deleting the request
        @param ipfs - the ipfs hash to be deleted
        @param payee - who to pay
    */
    function payOnDelivery(uint ipfs, address payable payee) internal {
        IPFSRequest memory q = requests[requestIndex[ipfs]];
        if (q.weiPayment > 0) {
            payee.transfer(q.weiPayment);
        }
        if (q.xyoPayment > 0) {
            xyoToken.safeTransfer(payee, q.xyoPayment);
        }
    }

    /** 
        Will refund the asker prior to deleting the request
        @param ipfs - the ipfs hash to be deleted
        @param refundee Who to pay the escrow balance too
    */
    function deleteRequestAndRefund(uint ipfs, address payable refundee) internal {
        payOnDelivery(ipfs, refundee);
        _deleteRequest(ipfs);
    }

    /** 
        Will delete the request and remove the request index
        @param ipfs - the ipfs hash to be deleted
    */
    function _deleteRequest(uint ipfs) private {
        uint qIndex = requestIndex[ipfs];
        uint lastQIndex = requests.length.sub(1);
        IPFSRequest memory lastRequest = requests[lastQIndex];

        requests[qIndex] = lastRequest;
        delete requests[lastQIndex];

        requests.length--;
        requestIndex[ipfs] = 0;
        requestIndex[lastRequest.ipfs] = qIndex;
    }

    /** Public array length getters */
    function numRequests() public view returns (uint) {
        return requests.length;
    }
}