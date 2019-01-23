pragma solidity >=0.5.0 <0.6.0;
import "./XyStakingToken.sol";
import "./token/ERC20/IERC20.sol";
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
        bool answered;
    }

    uint public genesis;


    // keyed is question ipfs as uint - stripped 2 bytes (hash fcn and size) and hex representation
    mapping(uint => Question) public questionsById; 
    uint[] public questionArray;

    mapping(uint => Block) public blocks; //The blocks in the chain

    uint[] public chain; // Store the chain as an array

    IERC20 public erc20;

    constructor(
        uint _genesis,
        address _token,
        address _stakeeToken,
        address _governance
    )
        public
        XyStakingToken(_token, _stakeeToken, _governance)
    {
        genesis = _genesis;
        erc20 = IERC20(_token);
    }


    /**
        @dev Escrow eth and xyo, making sure it covers the answer mining cost
        Stores new question in question pool
        @param question - the ipfs hash (first 2 bytes stripped) to identify the question
        @param xyoSender - who to deduct the xyo from for mining cost
        @param answerType - based on the type we know which callback to call (string or bool)
    */
    function submitQuestion(uint question, address xyoSender, uint8 answerType) 
        public
        payable
    {
        uint ethMining = params.get("xyEthMiningCost");
        uint xyoMining = params.get("xyXYOMiningCost");
        if (ethMining > 0) {
            require (msg.value >= ethMining, "Not enough eth to cover mining");
        }
        if (xyoMining > 0) {
            require (erc20.allowance(address(this), xyoSender) >= xyoMining, "Not enough XYO to cover mining");
            xyoToken.transferFrom(xyoSender, address(this), xyoMining);
        }

        Question memory q = Question (
            xyoMining,
            msg.value, 
            block.number,
            msg.sender,
            answerType,
            false
        );

        questionsById[question] = q;

        emit QuestionSubmitted(question, xyoMining, msg.value,  msg.sender, xyoSender);
    }

    /**
        @dev Builds a prefixed hash to mimic the behavior of eth_sign
        @param hash bytes32 Message hash to be prefixed
    */
    function prefixed(bytes32 hash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /*
        Submit a new block to the consensus chain. Verifies stake in consensus is over 51% of the network. 
        calls questions' callbacks with answers.  Creates new block and returns reward for successful creation.
        @param previousBlock - the prior block to maintain the 
        @param _questions - list of the ipfs question addresses (minus first 2 bytes)
        @param answers - byte array of answers
        @param signers - Stakees, aka diviners and must be passed in ascending order to check for dups
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
            uint(keccak256(m)), // 0 - newBlock
            0, // 1 - stake
            0, // 2 - lastStakee
            0, // 3 - bytesOffset
            0 // 4 - reward
        ];

        for (uint i = 0; i < signers.length; i++) {
            address signer = ecrecover(prefixed(bytes32(uintValues[0])), sigV[i], sigR[i], sigS[i]);
            require(signers[i] == signer, "Invalid Signer");
            require(uintValues[2] < uint(signer), "Signers array must be ascending");
            uintValues[2] = uint(signer);
            uintValues[1] = uintValues[1].add(stakeeStake[uint(signer)].activeStake);
        }
        // check sufficient stake by stakees subitted
        require (uintValues[1] >= totalActiveStake.mul(params.get("xyStakeQuorumPct")).div(100), "Not enough stake");

        for (uint i = 0; i < _questions.length; i++) {
          Question storage q = questionsById[_questions[i]];
          if (!q.answered) {
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
          q.answered = true;
        }
        Block memory b = Block(uintValues[0], previousBlock, block.number, msg.sender);
        chain.push(uintValues[0]);
        blocks[uintValues[0]] = b;
        emit BlockCreated(uintValues[0], previousBlock, uintValues[4], block.number, msg.sender);
        transferFrom(address(this), msg.sender, uintValues[4]);
    }

}