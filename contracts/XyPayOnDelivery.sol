pragma solidity >=0.5.0 <0.6.0;

import "./ownership/Ownable.sol";
import "./SafeMath.sol";
import "./XyStakingConsensus.sol";
import "./token/ERC20/IERC20.sol";
import "./IXyIntersectionQuestion.sol";


/**
 * @title A Payment on delivery contract
 * @dev Will escrow funds until an item is marked as delivered .
 */
contract XyPayOnDelivery is Ownable, IXyIntersectionQuestion {
  using SafeMath for uint;

  event QuestionAsked(uint indexed ipfs);
  event QuestionAnswered(uint indexed ipfs, uint weiOnDelivery, uint xyoOnDelivery, address payable beneficiary, bool didIntersect);
  event QuestionDeleted(uint indexed ipfs, address asker);

  XyStakingConsensus public scsc;
  IERC20 public xyoToken;

  struct Question {
    uint ipfs;
    uint weiOnDelivery;
    uint xyoOnDelivery;
    address payable beneficiary;
    address payable asker;
  }

  mapping(uint => uint) questionIndex;
  Question[] public questions;
  uint completionCost = .01 finney;
  uint8 answerType = 1; // Boolean intersection Question is type 1
  
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

  // This contract holds escrows pay on delivery payments for questions
  // Only question askers can get back if they ask for refund
  function() external payable { }

  /**
    @dev Stores the sent amount and emits Deposited event
    @param ipfs - the hash of the question (first 2 bytes stripped)
    @param xyo - the amount of XYO to pay on delivery (should include mining gas)
    @param weiOnDelivery - the amount of eth to pay on delivery
    @param beneficiary The destination address of the funds.
  */
  function submitQuestion(
    uint ipfs, 
    uint xyo, 
    uint weiOnDelivery, 
    address payable beneficiary
  ) 
    public payable 
  {
    uint miningGas = msg.value.sub(weiOnDelivery);
    uint xyoOnDelivery = xyo.sub(scsc.params().get("xyXYOMiningCost"));
    scsc.submitQuestion.value(miningGas)(ipfs, msg.sender, answerType);
    xyoToken.transferFrom(msg.sender, address(this), xyoOnDelivery);

    Question memory q = Question(
      ipfs, weiOnDelivery, xyoOnDelivery, beneficiary, msg.sender
    );
    questionIndex[ipfs] = questions.length;
    questions.push(q);
    emit QuestionAsked(ipfs);
  }

  /**
      @dev If intersection, transfer pay on delivery to beneficiary, delete question
      @param ipfs - the hash of the question (first 2 bytes stripped)
      @param didIntersect - the answer to the question if the item arrived
  */
  function completionBool(uint ipfs, bool didIntersect) public {
    require (msg.sender == address(scsc), "only scsc can complete questions");
    Question memory q = questions[questionIndex[ipfs]];

    if (didIntersect) {
      xyoToken.transferFrom(address(this), q.beneficiary, q.xyoOnDelivery);
      (q.beneficiary).transfer(q.weiOnDelivery);
      _deleteQuestion(ipfs);
    } else {
      // No intersection, refund to asker
      deleteQuestionAndRefund(ipfs);
    }

    emit QuestionAnswered(ipfs, q.weiOnDelivery, q.xyoOnDelivery, q.beneficiary, didIntersect);
  }

  /** 
      Will refund the asker prior to deleting the question
      @param ipfs - the ipfs hash to be deleted
  */
  function deleteQuestionAndRefund(uint ipfs) public {
    Question memory q = questions[questionIndex[ipfs]];
    require (msg.sender == q.asker || msg.sender == address(scsc), "Only question asker or scsc can erase question");

    if (q.weiOnDelivery > 0) {
      q.asker.transfer(q.weiOnDelivery);
    }
    if (q.xyoOnDelivery > 0) {
      xyoToken.transferFrom(address(this), q.asker, q.xyoOnDelivery);
    }
    _deleteQuestion(ipfs);
    emit QuestionDeleted(ipfs, q.asker);
  }

  /** 
      Will delete the question and remove the question index
      @param ipfs - the ipfs hash to be deleted
  */
  function _deleteQuestion(uint ipfs) private {
    uint qIndex = questionIndex[ipfs];
    uint lastQIndex = questions.length.sub(1);
    Question memory lastQuestion = questions[lastQIndex];

    questions[qIndex] = lastQuestion;
    delete questions[lastQIndex];

    questions.length--;
    questionIndex[ipfs] = 0;
    questionIndex[lastQuestion.ipfs] = qIndex;
  }
}