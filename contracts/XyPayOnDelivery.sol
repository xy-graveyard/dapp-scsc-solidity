pragma solidity >=0.5.0 <0.6.0;

import "./SafeMath.sol";
import "./XyStakingConsensus.sol";
import "./token/ERC20/IERC20.sol";
import "./IXyIntersectionRequest.sol";
import "./token/ERC20/SafeERC20.sol";


/**
 * @title A Payment on delivery contract
 * @dev Will escrow funds until an item is marked as delivered .
 */
contract XyPayOnDelivery is IXyIntersectionRequest {
  using SafeERC20 for IERC20;
  using SafeMath for uint;

  event RequestAsked(uint indexed ipfs);
  event BoolResponse(uint indexed ipfs, uint weiOnDelivery, uint xyoOnDelivery, address payable beneficiary, bool didIntersect);

  XyStakingConsensus public scsc;
  IERC20 public xyoToken;

  struct Request {
    uint ipfs;
    uint weiOnDelivery;
    uint xyoOnDelivery;
    address payable beneficiary;
    address payable asker;
  }

  mapping(uint => uint) requestIndex;
  Request[] public requests;
  uint completionCost = .01 finney;
  uint8 answerType = 1; // Boolean intersection Request is type 1
  
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
    @dev Stores the sent amount and emits Deposited event
    @param ipfs - the hash of the request (first 2 bytes stripped)
    @param xyoTotal - the amount of XYO to pay on delivery (should include mining gas)
    @param weiOnDelivery - the amount of eth to pay on delivery
    @param beneficiary The destination address of the funds.
  */
  function submitRequest(
    uint ipfs, 
    uint xyoTotal, 
    uint weiOnDelivery, 
    address payable beneficiary
  ) 
    public payable 
  {
    uint miningGas = msg.value.sub(weiOnDelivery);
    uint xyoOnDelivery = xyoTotal.sub(scsc.params().get("xyXYOMiningCost"));
    
    // remainder of value is stored on this address
    scsc.submitRequest.value(miningGas)(ipfs, msg.sender, answerType);
    if (xyoOnDelivery > 0) {
      xyoToken.transferFrom(msg.sender, address(this), xyoOnDelivery);
    }
    Request memory q = Request(
      ipfs, weiOnDelivery, xyoOnDelivery, beneficiary, msg.sender
    );
    requestIndex[ipfs] = requests.length;
    requests.push(q);
    emit RequestAsked(ipfs);
  }

  /**
      @dev If intersection, transfer pay on delivery to beneficiary, delete request
      @param ipfs - the hash of the request (first 2 bytes stripped)
      @param didIntersect - the answer to the request if the item arrived
  */
  function completionBool(uint ipfs, bool didIntersect) public {
    require (msg.sender == address(scsc), "only scsc can complete requests");
    Request memory q = requests[requestIndex[ipfs]];
    if (didIntersect) {
      deleteRequestAndRefund(ipfs, q.beneficiary);
    } else {
      // No intersection, refund to asker
      deleteRequestAndRefund(ipfs, q.asker);
    }
    emit BoolResponse(ipfs, q.weiOnDelivery, q.xyoOnDelivery, q.beneficiary, didIntersect);
  }

  /** 
      Will refund the asker prior to deleting the request
      @param ipfs - the ipfs hash to be deleted
  */
  function deleteRequestAndRefund(uint ipfs, address payable refundee) internal {
    Request memory q = requests[requestIndex[ipfs]];
    require (msg.sender == q.asker || msg.sender == address(scsc), "Only request asker or scsc can erase request");
    if (q.weiOnDelivery > 0) {
      refundee.transfer(q.weiOnDelivery);
    }
    if (q.xyoOnDelivery > 0) {
      xyoToken.safeTransfer(refundee, q.xyoOnDelivery);
    }
    _deleteRequest(ipfs);
  }

  /** 
      Will delete the request and remove the request index
      @param ipfs - the ipfs hash to be deleted
  */
  function _deleteRequest(uint ipfs) private {
    uint qIndex = requestIndex[ipfs];
    uint lastQIndex = requests.length.sub(1);
    Request memory lastRequest = requests[lastQIndex];

    requests[qIndex] = lastRequest;
    delete requests[lastQIndex];

    requests.length--;
    requestIndex[ipfs] = 0;
    requestIndex[lastRequest.ipfs] = qIndex;
  }
}