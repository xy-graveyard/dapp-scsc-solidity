pragma solidity >=0.5.0 <0.6.0;
import "./XyStakingToken.sol";
import "./XyERC20Token.sol"; // TODO remove for ERC20 
import "./BytesToTypes.sol";
import "./IXyIntersectionQuestion.sol";

 /**
    @title XyStakedConsensusAnswering
    @dev Manages the Stake for multiple clients in a decentralized consensus 
    system to trustlessly answer questions
  */
contract XyStakingConsensus is XyStakingToken, BytesToTypes {
    using SafeMath for uint;
    
    /** EVENT */
    event QuestionSubmitted(
        uint indexed question,
        uint xyoValue,
        uint reward,
        address indexed questionContract,
        address xyoSender
    );

    event BlockCreated(
        uint newBlock,
        uint previousBlock,
        uint reward,
        uint createdAtBlock,
        address blockProducer
    );

    // TODO implement challenge
    struct Challenge {
        uint block;
        address challenger;
    }

    struct Block {
        uint blockHash;
        uint previousBlock;
        uint createdAt;
        address creator;
    }

    struct Question {
        uint xyoValue;
        uint reward;
        uint createdAt;
        address questionContract;
        uint8 answerType;
    }

    uint public genesis;
    uint public ethMiningCost = .1 finney; // .1 finney == .0001 ether
    uint public xyoMiningCost = 1 ether; // 1 ether of XYO == 1 XYO as they have same decimals (18)

    // keyed is question ipfs as uint - stripped 2 bytes (hash fcn and size) and hex representation
    mapping(uint => Question) public questionsById; 
    uint[] public questionArray;

    mapping(uint => Block) public blocks; //The blocks in the chain
    mapping(uint => Challenge) public challenges; //Challenges

    mapping(address => uint) public xyoCosts; //The minimum XYO needed for given question contract
    mapping(address => uint) public miningCosts; //The minimum XYO needed for given question contract

    uint[] public chain; // Store the chain as an array
    uint public stakedConsensusNumerator = 2;
    uint public stakedConsensusDenominator = 3;

    XyERC20Token public erc20;

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
        erc20 = _token;
    }

    /*
        Enables contract owner to set min staking necessary to come to consensus
        TODO: Should we allow a minimum bounds?
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
    function submitQuestion(uint question, address xyoSender, uint8 answerType) 
        public
        payable
    {
        if (ethMiningCost > 0) {
            require (msg.value >= ethMiningCost, "Not enough eth to cover mining");
        }
        if (xyoMiningCost > 0) {
            require (erc20.allowance(address(this), xyoSender) >= xyoMiningCost, "Not enough XYO to cover mining");
            // escrow xyo token
            xyoToken.transferFrom(xyoSender, address(this), xyoMiningCost);
        }

        Question memory q = Question (
            xyoMiningCost,
            msg.value, 
            block.number,
            msg.sender,
            answerType
        );

        questionsById[question] = q;

        emit QuestionSubmitted(question, xyoMiningCost, msg.value,  msg.sender, xyoSender);
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
        calls questions' callbacks with answers.  Creates new block.
        @param previousBlock - the prior block to maintain the 
        @param _questions - list of the ipfs question addresses (minus first 2 bytes)
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

        // use static array to not run out of stack space
        uint[5] memory uintValues = [
            uint(keccak256(m)), // newBlock
            0, // stake
            0, // lastStakee
            0, // bytesOffset
            0 // reward
        ];

        for (uint i = 0; i < signers.length; i++) {
            address signer = ecrecover(prefixed(bytes32(uintValues[0])), sigV[i], sigR[i], sigS[i]);
            require(signers[i] == signer, "Invalid Signer");
            require(uintValues[2] < uint(signer), "Signers array must be ascending");
            uintValues[2] = uint(signer);
            uintValues[1] = uintValues[1].add(stakeeStake[uint(signer)].activeStake);
        }

        require (uintValues[1] >= totalActiveStake.mul(stakedConsensusNumerator).div(stakedConsensusDenominator), "Not enough stake");

        for (uint i = 0; i < _questions.length; i++) {
          Question memory q = questionsById[_questions[i]];
          if (q.answerType == 0) {
            IXyIntersectionQuestion(q.questionContract).completionBool(_questions[i], bytesToBool(uintValues[3], answers));
            uintValues[3] += 1;
            uintValues[4] = uintValues[4].add(q.reward);
          } else if (q.answerType == 1) {
            string memory result;
            bytesToString(uintValues[3], answers, bytes(result));
            // TODO when dapploy uses latest truffle
            // IXyIntersectionQuestion(q.questionContract).completionString(_questions[i], result);
            uintValues[3] += getStringSize(uintValues[3], answers);
          } 
        }
        Block memory b = Block(uintValues[0], previousBlock, block.number, msg.sender);
        chain.push(uintValues[0]);
        blocks[uintValues[0]] = b;
        emit BlockCreated(uintValues[0], previousBlock, uintValues[4], block.number, msg.sender);
        transferFrom(address(this), msg.sender, uintValues[4]);
    }

}