pragma solidity >=0.5.0 <0.6.0;

import "../node_modules/zos-lib/contracts/Initializable.sol";
import "./XyStakingModel.sol";
import "./IXyRequester.sol";

 /**
    @title XyStakingConsensus
    @dev Manages the Stake for multiple clients in a decentralized consensus 
    system to trustlessly answer requests
  */
contract XyStakingConsensus is Initializable, XyStakingModel {
    using SafeMath for uint;
    
    /** EVENTS */
    event RequestSubmitted(
        uint request,
        uint xyoBounty,
        uint weiMining,
        address requestSender,
        IXyRequester.RequestType requestType
    );

    event BlockCreated(
        uint blockHash,
        uint previousBlock,
        uint createdAtBlock,
        bytes32 payloadHash,
        address blockProducer
    );

    event RewardClaimed(
        address beneficiary,
        uint amount,
        uint stakerStake
    );

    /** STRUCTS */
    struct Block {
        uint previousBlock;
        uint blockHeight;
        uint createdAt;
        bytes32 supportingData;
        address creator;
    }

    struct Request {
        uint xyoBounty;
        uint weiMining;
        uint createdAt;
        address requestSender;
        IXyRequester.RequestType requestType;
        bool hasResponse;
    }

    // id should be unique (ie ipfs hash) maps to Request data
    mapping(uint => Request) public requestsById; 

    // an array of the requests useful for diviner reading
    uint[] public requestChain;

    mapping(uint => Block) public blocks; //The blocks in the blockChain
    uint[] public blockChain; // Store the blockChain as an array

    /**
        @param _token - The ERC20 token to stake with 
        @param _stakableToken - The ERC721 token to place stakes on 
        @param _governanceContract - The contract that governs the params and actions of the system
    */
    function initialize(
        address _token,
        address _stakableToken,
        address _governanceContract
    )
        initializer public
    {
        init(_token, _stakableToken, _governanceContract);
    }

    /** 
        @return the latest block submitted to the blockChain 
    */
    function getLatestBlock() 
        public 
        view 
        returns (uint _latest) 
    {
        if (blockChain.length == 0) {
            return 0;
        }
        return blockChain[blockChain.length-1];
    }

    /**
        Will verify proper mining fees have been applied
        @param xyoSender who to transfer the fees from (must have approved this contract)
        @param xyoBounty the amount the xyoSender is paying for this request
    */
    function _requireFeesAndTransfer(address xyoSender, uint xyoBounty) 
        private 
    {
        uint weiMiningMin = params.get("xyWeiMiningMin");
        uint xyoMiningMin = params.get("xyXYORequestBountyMin");
        if (weiMiningMin > 0) {
            require (msg.value >= weiMiningMin, "Not enough wei to cover mining");
        }
        if (xyoMiningMin > 0) {
            require (xyoBounty >= xyoMiningMin, "XYO Bounty less than minimum");
            require (xyoToken.allowance(xyoSender, address(this)) >= xyoMiningMin, "must approve SCSC for XYO mining fee");
            xyoToken.transferFrom(xyoSender, address(this), xyoMiningMin);
        }
    }

    /**
        @dev Withdraw reward balance can post same params via raw
        @param xyoBounty bounty for request
    */
    function withdrawRewardsRequest 
    (
        uint xyoBounty
    ) 
        public
        payable
        returns (uint)
    {
        uint requestId = uint(keccak256(abi.encodePacked(msg.sender, xyoBounty, block.number)));
        submitRequest(requestId, xyoBounty, msg.sender, IXyRequester.RequestType.WITHDRAW);
        return requestId;
    }

    /**
        @dev Escrow eth and xyo, making sure it covers the answer mining cost
        Stores new request in request pool
        @param request How to uniquely identify a request
        @param xyoBounty bounty for request
        @param xyoSender who to deduct the xyo from for mining cost
        @param requestType based on the type we know which callback to call (string or bool)
    */
    function submitRequest
    (
        uint request, 
        uint xyoBounty,
        address xyoSender, 
        IXyRequester.RequestType requestType
    ) 
        public
        payable
    {
        require (uint8(requestType) >= uint8(IXyRequester.RequestType.BOOL) && uint8(requestType) <= uint8(IXyRequester.RequestType.WITHDRAW), "Invalid request type");
        require (requestsById[request].createdAt == 0, "Duplicate request submitted");

        _requireFeesAndTransfer(xyoSender, xyoBounty);

        Request memory q = Request (
            xyoBounty,
            msg.value, 
            block.number,
            msg.sender,
            requestType,
            false
        );

        requestsById[request] = q;
        requestChain.push(request);

        emit RequestSubmitted(request, xyoBounty, msg.value,  msg.sender, requestType);
    }

    /**
        @dev Builds a prefixed hash to mimic the behavior of eth_sign
        @param msgHash bytes32 Message hash to be prefixed
        @return The hash prefixed with the Erhereum signed message (compatable with the eth_sign)
    */
    function prefixed
    (
        bytes32 msgHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
    }
    
    /**
        Requires the length of bytes is more than starting point + 32
        returns 32 bytes memory (reversed to uint) at start + 32 to memory[start]
        @param _bytes the bytes passed to pull uint from
        @param _start index in bytes to return uint
     */
    function _toUint(bytes memory _bytes, uint _start) private pure returns (uint256) {
        require(_bytes.length >= (_start + 32));
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }    


    /** 
        @dev Calls Request interface submitResponse function for each answer.
        Use for estimating gas of a request
        @param _requests the requests queried
        @param responseData the response data of all the requests
        @return The weiMining for submitting the new block
    */
    function handleResponses
    (
        uint[] memory _requests, 
        bytes memory responseData
    )
        internal 
        returns (uint)
    {
        uint byteOffset = 0;
        uint weiMining = 0;
        for (uint i = 0; i < _requests.length; i++) {
          Request storage q = requestsById[_requests[i]];
          if (!q.hasResponse) {
            q.hasResponse = true;
            weiMining = weiMining.add(q.weiMining);
            uint8 numBytes = q.requestType == IXyRequester.RequestType.BOOL ? 1 : 32;

            if (q.requestType == IXyRequester.RequestType.BOOL || q.requestType == IXyRequester.RequestType.UINT) {
                bytes memory result = new bytes(numBytes);
                for (uint8 j = 0; j < numBytes; j++) {
                    result[j] = responseData[byteOffset + j];
                }
                IXyRequester(q.requestSender).submitResponse(_requests[i], q.requestType, result);
            } else if (q.requestType == IXyRequester.RequestType.WITHDRAW) {
                uint amount = _toUint(responseData, byteOffset);
                require (amount <= totalStakeAndUnstake(q.requestSender), "Withdraw amount more than total staker's stake");
                emit RewardClaimed(q.requestSender, amount, totalStakeAndUnstake(q.requestSender));
                xyoToken.safeTransfer(q.requestSender, amount);
            } else {
                assert(false);
            }
            byteOffset += numBytes;
          }
        }
        return weiMining;
    }

    /** 
        @dev checks a message hash was signed by a list of signers via their sigs
        @param messageHash The hash of the message that was signed
        @param signers The in-order list of signers of the messgae
        @param sigR R values in signatures
        @param sigS S values in signatures
        @param sigV V values in signatures
    */
    function checkSigsAndStakes
    (
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

    function _createBlock(uint previousBlock, uint newBlock, bytes32 payloadHash, uint blockHeight) private {
        Block memory b = Block(previousBlock, blockHeight, block.number, payloadHash, msg.sender);
        blockChain.push(newBlock);
        blocks[newBlock] = b;
        emit BlockCreated(newBlock, previousBlock, block.number, payloadHash, msg.sender);
    }

    /**
        Submit a new block to the consensus blockChain. Verifies stake in consensus is over 51% of the network. 
        calls requests' callbacks with responses.  Creates new block and returns weiMining for successful creation.
        @param blockProducer the id of the stakable diviner in stakable tokens 
        @param previousBlock the prior block to maintain the 
        @param _requests list of the request ids (minus first 2 bytes)
        @param payloadData the hash of the supporting block data
        @param responses byte array of responses
        @param signers Stakees, aka diviners and must be passed in ascending order to check for dups
        @param sigR R values in signatures
        @param sigS S values in signatures
        @param sigV V values in signatures
        @return The hash of the new block
    */
    function submitBlock
    (
        uint blockProducer,
        uint previousBlock,
        uint stakingBlock,
        uint[] memory _requests,
        bytes32 payloadData,
        bytes memory responses,
        address[] memory signers,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        uint8[] memory sigV
    ) 
        public 
        returns (uint)
    {
        require (stakableToken.isBlockProducer(blockProducer), "Only approved BP can submit");
        require (stakableToken.ownerOf(blockProducer) == msg.sender, "Sender does not own BP");
        require (previousBlock == getLatestBlock(), "Incorrect previous block");
        bytes memory m = abi.encodePacked(previousBlock, stakingBlock, _requests, payloadData, responses);

        uint weiMining = handleResponses(_requests, responses);
        msg.sender.transfer(weiMining);

        uint newBlock = uint(keccak256(m));
        checkSigsAndStakes(newBlock, signers, sigR, sigS, sigV);
        _createBlock(previousBlock, newBlock, payloadData, stakingBlock);

        return newBlock;
    }

    /** Public array length getters */
    function numRequests() public view returns (uint) {
        return requestChain.length;
    }
    function numBlocks() public view returns (uint) {
        return blockChain.length;
    }
}