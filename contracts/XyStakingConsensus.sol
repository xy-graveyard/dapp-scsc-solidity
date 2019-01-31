pragma solidity >=0.5.0 <0.6.0;
import "./XyStakingModel.sol";
import "./BytesToTypes.sol";
import "./IXyRequester.sol";

 /**
    @title XyStakingConsensus
    @dev Manages the Stake for multiple clients in a decentralized consensus 
    system to trustlessly answer requests
  */
contract XyStakingConsensus is XyStakingModel, BytesToTypes {
    using SafeMath for uint;
    
    /** EVENT */
    event RequestSubmitted(
        uint request,
        uint xyoValue,
        uint reward,
        address callbackContract,
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

    struct Request {
        uint xyoValue;
        uint reward;
        uint createdAt;
        address callbackContract;
        uint8 answerType;
        bool answered;
    }

    // keyed is request ipfs as uint - stripped 2 bytes (hash fcn and size) and hex representation
    mapping(uint => Request) public requestsById; 
    uint[] public requestChain;

    mapping(uint => Block) public blocks; //The blocks in the blockChain
    uint[] public blockChain; // Store the blockChain as an array

    uint8 public BoolAnswerType = 1; 
    uint8 public StringAnswerType = 2; 

    constructor(
        address _token,
        address _stakeeToken,
        address _governance
    )
        public
        XyStakingModel(_token, _stakeeToken, _governance)
    {
    }

    /** 
        Returns the latest block submitted to the blockChain 
    */
    function getLatestBlock() public view returns (uint) {
        if (blockChain.length == 0) {
            return 0;
        }
        uint theBlock = blocks[blockChain[blockChain.length-1]].blockHash;
        require(theBlock != 0, "invalid latest block");
        return theBlock;
    }

    /**
        @dev Escrow eth and xyo, making sure it covers the answer mining cost
        Stores new request in request pool
        @param request - How to uniquely identify a request
        @param xyoSender - who to deduct the xyo from for mining cost
        @param answerType - based on the type we know which callback to call (string or bool)
    */
    function submitRequest(uint request, address xyoSender, uint8 answerType) 
        public
        payable
    {
        require (requestsById[request].createdAt == 0, "Duplicate request submitted");

        uint ethMining = params.get("xyEthMiningCost");
        uint xyoMining = params.get("xyXYOMiningCost");
        if (ethMining > 0) {
            require (msg.value >= ethMining, "Not enough eth to cover mining");
        }
        if (xyoMining > 0) {
            require (xyoToken.allowance(address(this), xyoSender) >= xyoMining, "Not enough XYO to cover mining");
            xyoToken.transferFrom(xyoSender, address(this), xyoMining);
        }

        Request memory q = Request (
            xyoMining,
            msg.value, 
            block.number,
            msg.sender,
            answerType,
            false
        );

        requestsById[request] = q;
        requestChain.push(request);

        emit RequestSubmitted(request, xyoMining, msg.value,  msg.sender, xyoSender);
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

    // function bytesToBool(uint _offst, bytes memory _input) public pure returns (bytes1 _output) {
    //     return _input[_offst];
    // }   
    // function byteAt(uint _offst, bytes memory _input) public pure returns (bytes memory _output) {
    //     return bytes(bytes1(_input[_offst]));
    // }   
        
    /** 
    @dev Calls Request interface submitResponse function for each answer.
    @param _requests the requests queried
    @param responseData the response data of all the requests
    */
    function respondAndCalcReward(uint[] memory _requests, bytes memory responseData)
        internal 
        returns (uint)
    {
        uint byteOffset = 0;
        uint reward = 0;
        for (uint i = 0; i < _requests.length; i++) {
          Request storage q = requestsById[_requests[i]];
          if (!q.answered) {
            reward = reward.add(q.reward);
            bytes memory result;
            if (q.answerType == BoolAnswerType) {
                result = new bytes(1);
                result[0] = responseData[byteOffset];
                IXyRequester(q.callbackContract).submitResponse(_requests[i], BoolAnswerType, result);
                byteOffset += 1;
            } else if (q.answerType == StringAnswerType) {
                bytesToString(byteOffset, responseData, result);
                IXyRequester(q.callbackContract).submitResponse(_requests[i], StringAnswerType, result);
                byteOffset += getStringSize(byteOffset, responseData);
            } 
            q.answered = true;
          }
        }
        return reward;
    }

    /** 
        @dev checks a message hash was signed by a list of signers via their sigs
        @param messageHash The hash of the message that was signed
        @param signers The in-order list of signers of the messgae
        @param sigR R values in signatures
        @param sigS S values in signatures
        @param sigV V values in signatures
    */
    function checkSigsAndStake(
        uint messageHash,
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
            address signer = ecrecover(prefixed(bytes32(messageHash)), sigV[i], sigR[i], sigS[i]);
            require(signers[i] > lastStakee , "Signers array must be ascending");
            lastStakee = signers[i];
            require(signers[i] == signer, "Invalid Signer");
            stake = stake.add(stakeeStake[uint(signer)].activeStake);
        }
        // check sufficient stake by stakees subitted
        require (stake > totalActiveStake.mul(params.get("xyStakeQuorumPct")).div(100), "Not enough stake");
    }

    /**
        Submit a new block to the consensus blockChain. Verifies stake in consensus is over 51% of the network. 
        calls requests' callbacks with answers.  Creates new block and returns reward for successful creation.
        @param previousBlock the prior block to maintain the 
        @param _requests list of the ipfs request addresses (minus first 2 bytes)
        @param answers byte array of answers
        @param signers Stakees, aka diviners and must be passed in ascending order to check for dups
        @param sigR R values in signatures
        @param sigS S values in signatures
        @param sigV V values in signatures
    */
    function submitBlock(uint previousBlock,
                         uint[] memory _requests,
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
        bytes memory m = abi.encodePacked(previousBlock, _requests, answers);

        require (keccak256(m) == keccak256(abi.encodePacked(test)), "Message is not packed correctly");

        uint newBlock = uint(keccak256(m));
        checkSigsAndStake(newBlock, signers, sigR, sigS, sigV);
        
        Block memory b = Block(newBlock, previousBlock, block.number, msg.sender);
        blockChain.push(newBlock);
        blocks[newBlock] = b;

        uint reward = respondAndCalcReward(_requests, answers);

        emit BlockCreated(newBlock, previousBlock, reward, block.number, msg.sender);
        msg.sender.transfer(reward);

        return newBlock;
    }

}