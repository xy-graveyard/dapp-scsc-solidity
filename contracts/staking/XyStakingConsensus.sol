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
        Implements IApprovalRecipient allows approveAndCall in one transaction
    */
    function receiveApproval(
        address _spender, 
        uint256 _value, 
        address,
        bytes calldata _extraData
    ) 
        whenActive
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


    function numBondStakes(bytes32 bondId) public view returns(uint) {
        return bondStakes[bondId].length;
    }
  
  function totalEjectStake(address staker) public view returns (uint) {
      uint activeAndCooldown = stakerStake[staker].activeStake + stakerStake[staker].cooldownStake;
    
      uint totalStake = stakerStake[staker].totalStake;
      if (totalStake != activeAndCooldown) {
          if (activeAndCooldown > totalStake) {
            return activeAndCooldown + stakerStake[staker].totalUnstake;
          }
        
      } 
      return totalStakeAndUnstake(staker);
    }

    /* 
        Done in conjunction with bonded stake
        Complete abandonment of this smart contract's state to reimburse all tokens
    */
    function eject(address beneficiary) public {
        uint amount = totalEjectStake(beneficiary);
        StakeAmounts storage amt = stakerStake[beneficiary];

        uint t = amt.totalStake;
        uint a = amt.activeStake;
        uint c = amt.cooldownStake;
        uint u = amt.totalUnstake;

        amt.totalStake = 0;
        amt.activeStake = 0;
        amt.cooldownStake = 0;
        amt.totalUnstake = 0;

        if (amount > 0) {
            SafeERC20.transfer(xyoToken, beneficiary, amount);
            emit EjectEvent(beneficiary, amount, t, a, c, u);
        }
    }
}