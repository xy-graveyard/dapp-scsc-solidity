pragma solidity >=0.5.0 <0.6.0;

import "./ownership/Ownable.sol";
import "./SafeMath.sol";
import "./XyStakingConsensus.sol";
import "./XyERC20Token.sol"; // TODO remove for ERC20 
import "./IXyIntersectionQuestion.sol";


/**
 * @title A Payment on delivery contract
 * @dev Will escrow funds until an item is marked as delivered .
 */
contract XyIntersectionQuestion is Ownable, IXyIntersectionQuestion {
  using SafeMath for uint;

  event QuestionAsked(uint indexed ipfs);
  event QuestionAnswered(uint indexed ipfs, uint weiOnDelivery, uint xyoOnDelivery, string itemA, string itemB, address payable beneficiary, bool didIntersect);
  event QuestionDeleted(uint indexed ipfs, address asker);

  XyStakingConsensus public scsc;
  XyERC20Token public xyoToken;

  struct Question {
    uint ipfs;
    uint weiOnDelivery;
    uint xyoOnDelivery;
    string itemA;
    string itemB;
    string marker;
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
  constructor (address stakingConsensus, address _xyoToken)
  public {
    scsc = XyStakingConsensus(stakingConsensus);
    xyoToken = XyERC20Token(_xyoToken);
  }

  // TODO this contract holds on to paymennt with no way to get it back
  function() external payable { }

  /**
  * @dev Stores the sent amount and emits Deposited event
  * @param beneficiary The destination address of the funds.
  */
  function submitQuestion(
    uint ipfs, 
    uint xyo, 
    uint weiOnDelivery, 
    string memory itemA, 
    string memory itemB, 
    address payable beneficiary, 
    string memory marker
  ) 
    public payable 
  {
    uint miningGas = msg.value.sub(weiOnDelivery);
    uint xyoOnDelivery = xyo.sub(scsc.xyoMiningCost());
    scsc.submitQuestion.value(miningGas)(ipfs, msg.sender, answerType);
    xyoToken.transferFrom(msg.sender, address(this), xyoOnDelivery);

    Question memory q = Question(
      ipfs, weiOnDelivery, xyoOnDelivery, itemA, itemB, marker, beneficiary, msg.sender
    );
    questionIndex[ipfs] = questions.length;
    questions.push(q);
    emit QuestionAsked(ipfs);
  }

  /**
      @dev Mark item as delivered and pay beneficiary!

  */
  function completionBool(uint question, bool didIntersect) public {
    require (msg.sender == address(scsc), "only scsc can complete questions");
    Question memory q = questions[questionIndex[question]];

    if (didIntersect) {
      xyoToken.transferFrom(address(this), q.beneficiary, q.xyoOnDelivery);
      (q.beneficiary).transfer(q.weiOnDelivery);
      _deleteQuestion(question);
    } else {
      // No intersection, refund the  amount
      deleteQuestionAndRefund(question);
    }

    emit QuestionAnswered(question, q.weiOnDelivery, q.xyoOnDelivery, q.itemA, q.itemB, q.beneficiary, didIntersect);
  }

  /* 
      TODO 
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

  /* 
      TODO 
  */
  function _deleteQuestion(uint questionId) private {
    uint qIndex = questionIndex[questionId];
    uint lastQIndex = questions.length.sub(1);
    Question memory lastQuestion = questions[lastQIndex];

    questions[qIndex] = lastQuestion;
    delete questions[lastQIndex];

    questions.length--;
    questionIndex[questionId] = 0;
    questionIndex[lastQuestion.ipfs] = qIndex;
  }
}