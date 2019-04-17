pragma solidity >=0.5.0 <0.6.0;

import "./utils/Initializable.sol";
import "./XyStakingModel.sol";
import "./IXyRequester.sol";

 /**
    @title XyStakingConsensus
    @dev Manages the Stake for multiple clients in a decentralized consensus 
    system to trustlessly answer requests
  */
contract XyStakingConsensus is Initializable, XyStakingModel {
    using SafeMath for uint;
    
    /** STRUCTS */
    struct Block {
        bytes32 previousBlock;
        bytes32 supportingData;
        uint stakingBlock;
        uint createdAt;
        address creator;
    }

    struct Request {
        uint xyoBounty;
        uint weiMining;
        uint createdAt;
        uint responseBlockNumber;
        address requestSender;
        uint8 requestType;
    }

    // id should be unique (ie ipfs hash) maps to Request data
    mapping(bytes32 => Request) public requestsById; 

    // an array of the requests useful for diviner reading
    bytes32[] public requestChain;

    mapping(bytes32 => Block) public blocks; //The blocks in the blockChain
    bytes32[] public blockChain; // Store the blockChain as an array

    /** EVENTS */
    event RequestSubmitted(
        bytes32 request,
        uint xyoBounty,
        uint weiMining,
        address requester,
        address xyoSender,
        uint8 requestType
    );

    event BlockCreated(
        bytes32 blockHash,
        bytes32 previousBlock,
        bytes32 supportingData,
        uint createdAtBlock,
        address blockProducer
    );

    event WithdrawClaimed(
        address beneficiary,
        uint amount,
        uint stakerStake
    );

    event Response (
        bytes32 request,
        uint responseBlock,
        uint result,
        uint8 responseType
    );
    /**
        @param _token - The ERC20 token to stake with 
        @param _blockProducerContract - The block producers 
        @param _governanceContract - The contract that governs the blockProducer and actions of the system
    */
    function initialize(
        address _token,
        address _blockProducerContract,
        address _governanceContract
    )
        initializer public
    {
        init(_token, _blockProducerContract, _governanceContract);
    }

    /** 
        @return the latest block submitted to the blockChain 
    */
    function getLatestBlock() 
        public 
        view 
        returns (bytes32) 
    {
        if (blockChain.length == 0) {
            return 0x0;
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
        uint weiMiningMin = govContract.get("xyWeiMiningMin");
        uint bountyMin = govContract.get("xyXYORequestBountyMin");
        if (weiMiningMin > 0) {
            require (msg.value >= weiMiningMin, "Not enough wei to cover mining");
        }
        if (xyoBounty > 0 || bountyMin > 0) {
            require (xyoBounty >= bountyMin, "XYO Bounty less than minimum");
            SafeERC20.transferFrom(xyoToken, xyoSender, address(this), xyoBounty);
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
        returns (bytes32)
    {
        bytes32 requestId = keccak256(abi.encodePacked(msg.sender, xyoBounty, block.number));
        submitRequest(requestId, xyoBounty, msg.sender, uint8(IXyRequester.RequestType.WITHDRAW));
        return requestId;
    }


    /** 
        Implements IApprovalRecipient allows approveAndCall in one transaction
    */
    function receiveApproval(
        address _spender, 
        uint256 _value, 
        address _token,
        bytes calldata _extraData
    ) 
        external 
    {
        require (_token == xyoToken, "Can only be called from the current token");
        (uint method, bytes memory data) = abi.decode(_extraData, (uint, bytes));
        
        if (method == 1) {
            (address staker, address stakee) = abi.decode(data, (address, address));
            stakeFrom(_spender, staker, stakee, _value);
        } else if (method == 2) {
            ( bytes32 request, uint xyoBounty, address xyoSender, uint8 requestType) = abi.decode(data, (bytes32, uint, address, uint8));
            submitRequest(request, xyoBounty, xyoSender, requestType);
        } else if (method == 3) {
            (address[] memory stakers, address[] memory stakees, uint[] memory amounts) = abi.decode(data, (address[], address[], uint[]));
            stakeMultiple(_spender, stakers, stakees, amounts);
        }
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
        bytes32 request, 
        uint xyoBounty,
        address xyoSender, 
        uint8 requestType
    ) 
        public
        payable
    {
        require (requestsById[request].createdAt == 0, "Duplicate request submitted");

        _requireFeesAndTransfer(xyoSender, xyoBounty);

        Request memory q = Request (
            xyoBounty,
            msg.value, 
            block.number,
            0,
            msg.sender,
            requestType
        );

        requestsById[request] = q;
        requestChain.push(request);

        emit RequestSubmitted(request, xyoBounty, msg.value,  msg.sender, xyoSender, requestType);
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
    function _toUintFromBytes(bytes memory _bytes, uint _start, uint bytesLen) private pure returns (uint256) {
        require(_bytes.length >= (_start + bytesLen));
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
        @param responses the response data of all the requests
        @return The weiMining for submitting the new block
        Will revert if the request does not exist, or the withdraw request is more htna the staker stake
    */
    function handleResponses
    (
        bytes32[] memory _requests, 
        bytes memory responses
    )
        internal 
        returns (uint)
    {
        uint byteOffset = 0;
        uint weiMining = 0;
        for (uint i = 0; i < _requests.length; i++) {
            Request storage q = requestsById[_requests[i]];
            require (q.createdAt > 0, "Passed a request that does not exist");
            uint numBytes = q.requestType == uint8(IXyRequester.RequestType.BOOL_CALLBACK)
                         || q.requestType == uint8(IXyRequester.RequestType.BOOL) ? 1 : 32;

            q.responseBlockNumber = numBlocks().add(1);
            weiMining = weiMining.add(q.weiMining);

            if (q.requestType == uint8(IXyRequester.RequestType.WITHDRAW)) {
                uint amount = _toUintFromBytes(responses, byteOffset, numBytes);
                require (amount <= totalStakeAndUnstake(q.requestSender), "Withdraw amount more than total staker's stake");
                emit WithdrawClaimed(q.requestSender, amount, totalStakeAndUnstake(q.requestSender));
                SafeERC20.transfer(xyoToken, q.requestSender, amount);
            } else {
                bytes memory result = new bytes(numBytes);
                for (uint j = 0; j < numBytes; j++) {
                    result[j] = responses[byteOffset + j];
                }
                if (q.requestType == uint8(IXyRequester.RequestType.BOOL_CALLBACK) 
                    || q.requestType == uint8(IXyRequester.RequestType.UINT_CALLBACK)) {
                    IXyRequester(q.requestSender).submitResponse(_requests[i], q.requestType, result);
                } 
                emit Response(_requests[i], q.responseBlockNumber, _toUintFromBytes(result, 0, numBytes), q.requestType);
            }
            byteOffset += numBytes;
        }
        
        return weiMining;
    }

    /** 
        @dev checks a message hash was signed by a list of signers via their sigs
        @param messageHash The hash of the message that was signed
        @param signers The in-order list of signers of the message
        @param sigR R values in signatures
        @param sigS S values in signatures
        @param sigV V values in signatures
    */
    function checkSigsAndStakes
    (
        bytes32 messageHash,
        address[] memory signers,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        uint8[] memory sigV
    )
        view
        internal 
    {
        bytes32 prefixedHash = prefixed(messageHash);
        address lastStakee = address(0);
        uint stake = 0;
        for (uint i = 0; i < signers.length; i++) {
            address signer = ecrecover(prefixedHash, sigV[i], sigR[i], sigS[i]);
            require(signers[i] > lastStakee , "Signers array must be ascending");
            lastStakee = signers[i];
            require(signers[i] == signer, "Signature mis-match");
            stake = stake.add(stakeeStake[lastStakee].activeStake);
        }
        // check sufficient stake by stakees subitted
        require (stake > totalActiveStake.mul(govContract.get("xyStakeSuccessPct")).div(100), "Not enough stake");
    }

    function _createBlock(bytes32 previousBlock, bytes32 newBlock, bytes32 supportingData, uint stakingBlock) private {
        Block memory b = Block(previousBlock, supportingData, stakingBlock, block.number,  msg.sender);
        blockChain.push(newBlock);
        blocks[newBlock] = b;
        emit BlockCreated(newBlock, previousBlock, supportingData, block.number, msg.sender);
    }

    /**
        Submit a new block to the consensus blockChain. Verifies stake in consensus is over 51% of the network. 
        calls requests' callbacks with responses.  Creates new block and returns weiMining for successful creation.
        @param previousBlock the prior block to maintain the 
        @param stakingBlock the block number diviners get staking data for
        @param _requests list of the request ids (minus first 2 bytes)
        @param supportingData the hash of the supporting block data
        @param responses byte array of responses
        @param signers Stakees, aka diviners and must be passed in ascending order to check for dups
        @param sigR R values in signatures
        @param sigS S values in signatures
        @param sigV V values in signatures
        @return The hash of the new block
    */
    function submitBlock
    (
        bytes32 previousBlock,
        uint stakingBlock,
        bytes32[] memory _requests,
        bytes32 supportingData,
        bytes memory responses,
        address[] memory signers,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        uint8[] memory sigV
    ) 
        public 
        returns (bytes32)
    {
        require (blockProducerContract.exists(msg.sender), "Only approved BP can submit");
        require (previousBlock == getLatestBlock(), "Incorrect previous block");
        require (_requests.length > 0, "No requests in block");
        
        bytes32 newBlock = keccak256(abi.encodePacked(previousBlock, stakingBlock, _requests, supportingData, responses));
        uint weiMining = handleResponses(_requests, responses);
        msg.sender.transfer(weiMining);

        checkSigsAndStakes(newBlock, signers, sigR, sigS, sigV);
        _createBlock(previousBlock, newBlock, supportingData, stakingBlock);

        return newBlock;
    }

    function blockForRequest(bytes32 requestId) 
        public view 
        returns (
            bytes32 previousBlock,
            bytes32 supportingData,
            uint stakingBlock,
            uint createdAt,
            address creator
        ) 
    {
        Request memory r = requestsById[requestId];
        if (r.responseBlockNumber > 0) {
            bytes32 blockId = blockChain[r.responseBlockNumber.sub(1)];
            if (blockId != 0) {
                previousBlock = blocks[blockId].previousBlock;
                supportingData = blocks[blockId].supportingData;
                stakingBlock = blocks[blockId].stakingBlock;
                createdAt = blocks[blockId].createdAt;
                creator = blocks[blockId].creator;
            }
        }
    }

    function supportingDataForRequest(bytes32 requestId) public view returns (bytes32 supportingData) {
        (,supportingData,,,) = blockForRequest(requestId);
    }

    function numRequests() public view returns (uint) {
        return requestChain.length;
    }
    
    function numBlocks() public view returns (uint) {
        return blockChain.length;
    }
}