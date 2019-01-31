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

  event IntersectResponse(uint ipfs, uint weiOnDelivery, uint xyoOnDelivery, address payable beneficiary, bool didIntersect);

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
  public {
    scsc = XyStakingConsensus(stakingConsensus);
    xyoToken = IERC20(_xyoToken);
  }

  // This contract holds escrows pay on delivery payments for requests
  // Only request askers can get back if they ask for refund
  // function() external payable { }

  /**
    @dev API for client to request an intersection question
    @param ipfs - the hash of the request (first 2 bytes stripped)
    @param xyoTotal - the amount of XYO to pay on delivery (should include mining gas)
    @param weiOnDelivery - the amount of eth to pay on delivery
    @param beneficiary The destination address of the funds.
  */
  function submitIPFSRequest(
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
    scsc.submitRequest.value(miningGas)(ipfs, msg.sender, 1);
    if (xyoOnDelivery > 0) {
      xyoToken.transferFrom(msg.sender, address(this), xyoOnDelivery);
    }
    IPFSRequest memory q = IPFSRequest(
      ipfs, weiOnDelivery, xyoOnDelivery, block.number, 0, beneficiary, msg.sender
    );
    requestIndex[ipfs] = requests.length;
    requests.push(q);
}

  /**
      @dev If intersection, transfer pay on delivery to beneficiary, delete request
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
    emit IntersectResponse(q.ipfs, q.weiOnDelivery, q.xyoOnDelivery, q.beneficiary, intersection);
  }

  /** 
      Will refund the asker prior to deleting the request
      @param ipfs - the ipfs hash to be deleted
      @param payee - who to pay
  */
  function payOnDelivery(uint ipfs, address payable payee) internal {
    IPFSRequest memory q = requests[requestIndex[ipfs]];
    require (msg.sender == q.asker || msg.sender == address(scsc), "Only request asker or scsc can erase request");
    if (q.weiOnDelivery > 0) {
      payee.transfer(q.weiOnDelivery);
    }
    if (q.xyoOnDelivery > 0) {
      xyoToken.safeTransfer(payee, q.xyoOnDelivery);
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
}