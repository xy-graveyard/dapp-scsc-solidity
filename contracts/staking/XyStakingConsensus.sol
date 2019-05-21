pragma solidity >=0.5.0 <0.6.0;

import "../utils/Initializable.sol";
import "./XyStakingModel.sol";
import "../IXyRequester.sol";

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

    // the array of request ids
    bytes32[] public requestChain;
    // the requests in the requestChain
    mapping(bytes32 => Request) public requestsById; 
    // the array of block ids
    bytes32[] public blockChain; 
    // The blocks in the blockChain
    mapping(bytes32 => Block) public blocks; 

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

    // mapping from stake id to bond id
    mapping (bytes32 => bytes32) public bondedStake;
    // mapping from bond id to stake ids
    mapping (bytes32 => bytes32[]) public bondStakes;
    // mapping from stake id to index in bond stake
    mapping (bytes32 => uint) public bondStakeIndex;

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
        address,
        bytes calldata _extraData
    ) 
        external 
    {
        require (msg.sender == xyoToken, "sender must be token");
        (uint method, bytes memory data) = abi.decode(_extraData, (uint, bytes));
        
        if (method == 1) {
            (address staker, address stakee) = abi.decode(data, (address, address));
            stakeFrom(_spender, staker, stakee, _value);
        } else if (method == 2) {
            ( bytes32 request, uint xyoBounty, address xyoSender, uint8 requestType) = abi.decode(data, (bytes32, uint, address, uint8));
            submitRequestFrom(_spender, request, xyoBounty, xyoSender, requestType);
        } else if (method == 3) {
            (address[] memory stakers, address[] memory stakees, uint[] memory amounts) = abi.decode(data, (address[], address[], uint[]));
            stakeMultiple(_spender, stakers, stakees, amounts);
        } else if (method == 4) {
            (bytes32 bondId, address staker, address[] memory stakees, uint[] memory amounts) = abi.decode(data, (bytes32, address, address[], uint[]));
            _stakeAndBond(bondId, _spender, staker, stakees, amounts);
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
        submitRequestFrom(msg.sender, request, xyoBounty, xyoSender, requestType);
    }

    function submitRequestFrom
    (   
        address from,
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
            xyoBounty,      // bounty
            msg.value,      // wei for mining
            block.number,   // created at
            0,              // response block num           
            from,           // requestSender (receives response cb)
            requestType     // type of request
        );

        requestsById[request] = q;
        requestChain.push(request);

        emit RequestSubmitted(request, xyoBounty, msg.value, from, xyoSender, requestType);
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
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
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

    /**
        Returns a block for a given request id or a undefined block
        @param requestId the block this request was responded on
    */
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

    /**
        Returns supporting data for a given request id
        @param requestId the block this request was responded on
        @return content addressable hash of the data
    */
    function supportingDataForRequest(bytes32 requestId) public view returns (bytes32 supportingData) {
        (,supportingData,,,) = blockForRequest(requestId);
    }

    function numRequests() public view returns (uint) {
        return requestChain.length;
    }
    
    function numBlocks() public view returns (uint) {
        return blockChain.length;
    }

    /* Network Staking Support */

    /**
        Called from StakingModel base class to see if this is bonded stake
    */
    function isBondedStake(bytes32 stakingId) internal view returns (bool) {
        return bondedStake[stakingId] != 0;
    }

    /**
        stakes a bonded stake
        @param bondId - the bond id to ensure the correct stake
        @param issuer - Who provides the xyo
        @param staker - the beneficiary of the stake
        @param stakees - the stakees to stake
        @param amounts - the amounts to stake by stakee
    */
    function _stakeAndBond (
        bytes32 bondId, 
        address issuer, 
        address staker, 
        address[] memory stakees, 
        uint[] memory amounts
    ) 
        private 
    {
        require(stakees.length == amounts.length, "bad inputs");
        address lastStakee = address(0);
        for (uint i = 0; i < stakees.length; i++) {
            require(stakees[i] > lastStakee , "Stakees array must be unique and ascending");
            lastStakee = stakees[i];
            bytes32 stakingId = stakeFrom(issuer, staker, stakees[i], amounts[i]);
            bondedStake[stakingId] = bondId;
            bondStakeIndex[stakingId] = bondStakes[bondId].length;
            bondStakes[bondId].push(stakingId);
            _activateStake(stakingId, blockProducerContract.exists(stakees[i]) != true);
        }
    } 

    function _removeBondedStake(
        bytes32 bondId, 
        bytes32 stakingId 
    )
        private
    {
        uint lastI = bondStakes[bondId].length.sub(1);
        uint index = bondStakeIndex[stakingId];

        bytes32 last = bondStakes[bondId][lastI];
        bondStakes[bondId][index] = last;

        bondStakes[bondId].length--;
        bondStakeIndex[stakingId] = 0;
        
        bondStakeIndex[last] = index;
        bondedStake[stakingId] = 0;
    }

    /**
        Unstakes/withdraws to bonded stake
        @param bondId - the bond id to ensure the correct stake
        @param stakingId - the id of the stake to withdraw to bond contract
    */
    function unstakeBonded (
        bytes32 bondId, 
        bytes32 stakingId
    ) 
        external 
    {
        address bondContract = address(govContract.get('XyBondContract'));
        require(msg.sender == bondContract, "only from bond contract");
        require(bondId != 0 && bondId == bondedStake[stakingId], "Stake not bonded to this bond");
        Stake storage data = stakeData[stakingId];
        if (data.unstakeBlock==0) {
            updateCacheOnUnstake(data);
            emit StakeEvent(stakingId, data.amount, data.staker, data.stakee, StakeTransition.UNSTAKED);
        }
        _removeBondedStake(bondId, stakingId);
        _withdrawStakeData(stakingId, data);
    }

    function numBondStakes(bytes32 bondId) public view returns(uint) {
        return bondStakes[bondId].length;
    }
}