pragma solidity >=0.5.0 <0.6.0;
import "./XyStakingModel.sol";
import "./BytesToTypes.sol";
import "./IXyIntersectionRequest.sol";

 /**
    @title XyStakedConsensusAnswering
    @dev Manages the Stake for multiple clients in a decentralized consensus 
    system to trustlessly answer questions
  */
contract XyStakingConsensus is XyStakingModel, BytesToTypes {
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
        uint blockHash,
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

    // keyed is question ipfs as uint - stripped 2 bytes (hash fcn and size) and hex representation
    mapping(uint => Question) public questionsById; 

    mapping(uint => Block) public blocks; //The blocks in the chain

    uint[] public chain; // Store the chain as an array

    constructor(
        address _token,
        address _stakeeToken,
        address _governance
    )
        public
        XyStakingModel(_token, _stakeeToken, _governance)
    {
    }

    function getLatestBlock() public view returns (uint) {
        if (chain.length == 0) {
            return 0;
        }
        uint theBlock = blocks[chain[chain.length-1]].blockHash;
        require(theBlock != 0, "invalid latest block");
        return theBlock;
    }

    /**
        @dev Escrow eth and xyo, making sure it covers the answer mining cost
        Stores new question in question pool
        @param question - the ipfs hash (first 2 bytes stripped) to identify the question
        @param xyoSender - who to deduct the xyo from for mining cost
        @param answerType - based on the type we know which callback to call (string or bool)
    */
    function submitRequest(uint question, address xyoSender, uint8 answerType) 
        public
        payable
    {
        uint ethMining = params.get("xyEthMiningCost");
        uint xyoMining = params.get("xyXYOMiningCost");
        if (ethMining > 0) {
            require (msg.value >= ethMining, "Not enough eth to cover mining");
        }
        if (xyoMining > 0) {
            require (xyoToken.allowance(address(this), xyoSender) >= xyoMining, "Not enough XYO to cover mining");
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


    function answerQuestions(uint[] memory _questions, bytes memory answers)
        internal 
        returns (uint)
    {
        uint byteOffset = 0;
        uint reward = 0;
        for (uint i = 0; i < _questions.length; i++) {
          Question storage q = questionsById[_questions[i]];
          if (!q.answered) {
            reward = reward.add(q.reward);
            if (q.answerType == 1) {
                IXyIntersectionRequest(q.questionContract).completionBool(_questions[i], bytesToBool(byteOffset, answers));
                byteOffset += 1;
            } else if (q.answerType == 2) {
                string memory result;
                bytesToString(byteOffset, answers, bytes(result));
                // TODO when dapploy uses latest truffle
                // IXyIntersectionRequest(q.questionContract).completionString(_questions[i], result);
                byteOffset += getStringSize(byteOffset, answers);
            } 
            q.answered = true;
          }
        }
        return reward;
    }


    function checkSigsAndStake(
        uint newBlock,
        address[] memory signers,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        uint8[] memory sigV
    )
        view
        internal 
    {

        address lastStakee = address(0);
        uint stake = 0;
        for (uint i = 0; i < signers.length; i++) {
            address signer = ecrecover(prefixed(bytes32(newBlock)), sigV[i], sigR[i], sigS[i]);
            require(signers[i] > lastStakee , "Signers array must be ascending");
            lastStakee = signers[i];
            require(signers[i] == signer, "Invalid Signer");
            stake = stake.add(stakeeStake[uint(signer)].activeStake);
        }
        // check sufficient stake by stakees subitted
        require (stake > totalActiveStake.mul(params.get("xyStakeQuorumPct")).div(100), "Not enough stake");
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
                         uint8[] memory sigV,
                         bytes memory test) 
        public 
        returns (uint)
    {
        require(previousBlock == getLatestBlock(), "Incorrect previous block");
        bytes memory m = abi.encodePacked(previousBlock, _questions, answers);

        require (keccak256(m) == keccak256(abi.encodePacked(test)), "Message is not packed correctly");

        uint newBlock = uint(keccak256(m));
        checkSigsAndStake(newBlock, signers, sigR, sigS, sigV);
        
        Block memory b = Block(newBlock, previousBlock, block.number, msg.sender);
        chain.push(newBlock);
        blocks[newBlock] = b;

        uint reward = answerQuestions(_questions, answers);

        emit BlockCreated(newBlock, previousBlock, reward, block.number, msg.sender);
        msg.sender.transfer(reward);

        return reward;
    }

}