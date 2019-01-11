pragma solidity >=0.5.0 <0.6.0;
import "./XyStakingToken.sol";
import "./XyERC20Token.sol"; // TODO remove for ERC20 
import "./BytesToTypes.sol";

contract XyQuestionI {
    function completionBool(uint, bool) public {}
    function completionString(uint, string memory) public {}
}

 /**
    @title XyStakedConsensusAnswering
    @dev Manages the Stake for multiple clients in a decentralized consensus 
    system to trustlessly answer questions
  */
contract XyStakingConsensus is XyStakingToken, BytesToTypes {
    using SafeMath for uint;
    
    /** EVENTS */
    event QuestionAsked(
        uint indexed question,
        uint xyoValue,
        uint miningReward,
        address indexed questionContract,
        address xyoSender
    );

    struct Challenge {
        uint block;
        address challenger;
    }

   struct Block {
        uint previousBlock;
        address creator;
        uint8 answerLen;
        uint8 answerType;
        bytes answers;
    }

    struct Question {
        uint xyoValue;
        uint miningReward;
        uint creationBlock;
        address questionContract;
        uint8 answerType;
    }


    uint public genesis;
    uint public current;
    uint public minMiningCost = .1 finney; // .1 finney == .0001 ether

    // keyed is question ipfs as uint - stripped 2 bytes (hash fcn and size) and hex representation
    mapping(uint => Question) public questionsById; 
    uint[] public questionArray;

    mapping(uint => Block) public blocks; //The blocks in the chain
    mapping(uint => Challenge) public challenges; //The blocks in the chain

    mapping(address => uint) public xyoCosts; //The minimum XYO needed for given question contract
    mapping(address => uint) public miningCosts; //The minimum XYO needed for given question contract

    uint[] public chain; // the chain of blocks as an array
    uint public stakedConsensusNumerator = 2;
    uint public stakedConsensusDenominator = 3;

    constructor(
        uint _genesis,
        XyERC20Token _token,
        ERC721 _stakableToken,
        uint _stakeCooldown,
        uint _unstakeCooldown
    )
        public
        XyStakingToken(_token, _stakableToken, _stakeCooldown, _unstakeCooldown)
    {
        genesis = _genesis;
    }

    /*
        Enables contract owner to set min staking necessary to come to consensus
    */
    function setStakingConsensus(uint numerator, uint denominator) 
        onlyOwner 
        public 
    {
        stakedConsensusNumerator = numerator;
        stakedConsensusDenominator = denominator;
    }

    /*
        Escrow value sent, making sure it covers the answer mining cost
        Escrow xyo to be paid to network as part of question cost
    */
    function submitQuestion(uint question, uint xyoValue, address xyoSender, uint8 answerType) 
        public
        payable
    {
        // TODO: should we require the sender follows expected interface?
        require (msg.value > minMiningCost, "Not enough eth to cover minimum diviner mining");

        Question memory q = Question (
            xyoValue,
            msg.value,
            block.number,
            msg.sender,
            answerType
        );
        questionsById[question] = q;
        
        // escrow xyo token
        xyoToken.transferFrom(xyoSender, address(this), xyoValue);
        // TODO what do we do with excess XYO on contract
        emit QuestionAsked(question, xyoValue, msg.value,  msg.sender, xyoSender);
    }

    /**
        @dev Builds a prefixed hash to mimic the behavior of eth_sign
        @param _hash bytes32 Message hash to be prefixed
    */
    function prefixed(bytes32 _hash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash));
    }

    /*
        Submit a new block to the consensus chain
        Verifies all signers signed the data for new block, verifies their stake is sufficient,
        calls the question's callback with the answer.
        @param previousBlock - the prior block to maintain the 
        @param _questions - list of the ipfs question addresses (minus first 2 bytes)
        @param answerType - 0 == bool, 1 == string, TODO create mapping
        @param answers - byte array of answers
        @param signers - Who signed the answers (must be passed in ascending order to check for dups)
        @param sigR, sigS, sigV - Signatures of signers
    */
    function submitBlock(uint previousBlock,
                         uint[] memory _questions,
                         bytes memory answers,
                         address[] memory signers,
                         bytes32[] memory sigR,
                         bytes32[] memory sigS,
                         uint8[] memory sigV) 
        public 
    {
        // Off to good start, noone front running us
        require(previousBlock == chain[chain.length-1], "Incorrect previous block");

        bytes memory m = abi.encodePacked(previousBlock, _questions, answers);
        uint stake = 0;
        uint lastStakee = 0;
        for (uint i = 0; i < signers.length; i++) {
            address signer = ecrecover(prefixed(keccak256(m)), sigV[i], sigR[i], sigS[i]);
            require(signers[i] == signer, "Invalid Signer");
            require(lastStakee < uint(signer), "Signers array must be ascending");
            stake = stake.add(stakeeStake[uint(signer)].activeStake);
        }

        require (stake >= totalActiveStake.mul(stakedConsensusNumerator).div(stakedConsensusDenominator), "Not enough stake");

        uint bytesOffset = 0;
        for (uint i = 0; i < _questions.length; i++) {
          Question memory q = questionsById[_questions[i]];
          if (q.answerType == 0) {
            XyQuestionI(q.questionContract).completionBool(_questions[i], bytesToBool(bytesOffset,answers));
            bytesOffset += 1;
          } else if (q.answerType == 1) {
            string memory result;
            bytesToString(bytesOffset, answers, bytes(result));
            XyQuestionI(q.questionContract).completionString(_questions[i], result);
            bytesOffset += getStringSize(bytesOffset, answers);
          } 
        }
    }

}