pragma solidity >=0.5.0 <0.6.0;

import "./XyStakingConsensus.sol";
import "../utils/SafeMath.sol";
import "../token/ERC20/SafeERC20.sol";
import "../token/ERC20/IXYOERC20.sol";
import "../utils/Initializable.sol";
import "../access/GovernorRole.sol";

contract XyBondedStake is GovernorRole, Initializable {
    using SafeMath for uint;

    address public erc20;
    address public consensus;
    mapping (bytes32 => address) public stakeIdManager;

    event BondDeposit(bytes32 bondId, address beneficiary, uint amount, uint expiration);
    event BondWithdraw(bytes32 bondId, address beneficiary, uint amount);
    event BondStake(bytes32 bondId, address sender, address beneficiary, uint amount);
    event BondUnstake(bytes32 bondId, address sender, bytes32 stakingId, uint amount);

    struct BondedStake {
        uint value;             // amount staked
        uint expirationSec;     // expiration date in seconds
        uint creationSec;       // creation date in seconds
        uint allocated;         // number allocated to node stake
        address owner;          // who owns the stake
        uint8 interest;         // possibly add interest or relationship here
    }

    mapping (bytes32 => BondedStake) public bondedStake;
    mapping (bytes32 => uint) public bondedStakeIndex;
    mapping (address => bytes32[]) public stakerStake;
    bytes32[] public bondedStakes;

    function initialize (
        address _token,
        address _consensusContract
    )
        initializer 
        public
    {
        erc20 = _token;
        consensus = _consensusContract;
    }

    /**
        Must approve before deposit can transfer in token
    */
    function deposit (uint xyoAmount, uint expirationDate) 
        public 
    {
        depositTo(msg.sender, xyoAmount, expirationDate);
    }

    function receiveApproval(
        address _spender, 
        uint256 _value, 
        address _token,
        bytes calldata _extraData
    ) 
        external 
    {
        require (_token == erc20, "Call from the current token");
        require (msg.sender == _token, "Sender not token"); 
        (uint expireDate) = abi.decode(_extraData, (uint));

        depositTo(_spender, _value, expireDate);
    }

    function depositTo (address to, uint xyoAmount, uint expirationDate) 
        internal 
    {
        bytes32 bondId = keccak256(abi.encode(to, xyoAmount, expirationDate, block.number));
        BondedStake memory ns = BondedStake(
            xyoAmount,
            expirationDate,
            block.timestamp,
            0,
            to,
            0
        );
        bondedStakeIndex[bondId] = bondedStakes.length;
        bondedStake[bondId] = ns;
        stakerStake[to].push(bondId);
        bondedStakes.push(bondId);
        
        SafeERC20.transferFrom(erc20, to, address(this), xyoAmount);
        emit BondDeposit(bondId, to, xyoAmount, expirationDate);
    }

    function withdrawTo (bytes32 bondId, address to) 
        public
    {
        BondedStake storage bs = bondedStake[bondId];
        uint withdrawAmount = bs.value;
        require (withdrawAmount > 0, "Bond has no value");
        bs.value = 0; // erase value of bond
        bool isOwner = msg.sender == bs.owner;
        require (bs.allocated == 0, "Bond must have no allocated stake");
        require (isOwner || isGovernor(msg.sender), "Only owner or governor can withdraw");
        if (isOwner) {
            require (now > bs.expirationSec, "Bond is still active");
        }
        SafeERC20.transfer(erc20, to, withdrawAmount);

        emit BondWithdraw(bondId, to, withdrawAmount);
    }

    function unstake (bytes32 bondId, bytes32 stakingId) 
        public  
    {
        bytes32 checkBondId = XyStakingConsensus(consensus).bondedStake(stakingId);
        (uint amount,,,,,,) = XyStakingConsensus(consensus).stakeData(stakingId);
        require(checkBondId == bondId, "Stake needs to be bonded");

        BondedStake storage bs = bondedStake[bondId];
        bool isOwner = msg.sender == bs.owner;
        require (isOwner || isGovernor(msg.sender), "Only owner or governor can unstake");
        
        require(bs.allocated >= amount, "Cannot unstake over bond allocation");
        bs.allocated = bs.allocated.sub(amount);

        // will fail if already withdrew  
        XyStakingConsensus(consensus).unstakeBonded(bondId, stakingId, amount);

        emit BondUnstake(bondId, msg.sender, stakingId, amount);
    }

    function stake (bytes32 bondId, address payable beneficiary, address[] memory stakees, uint[] memory amounts)
        public
    {
        BondedStake storage bs = bondedStake[bondId];
        bool isOwner = msg.sender == bs.owner;
        require (isOwner || isGovernor(msg.sender), "Only owner or governor can stake");
        
        uint total = 0;
        for (uint i = 0; i < amounts.length; i++) {
            total = total.add(amounts[i]);
        }
        bs.allocated = bs.allocated.add(total);

        require (bs.allocated <= bs.value, "Insufficient bond balance");

        // stake stakees with amounts
        bytes memory encoded = abi.encode(bondId, beneficiary, stakees, amounts);
        bytes memory methodData = abi.encode(4, encoded);
        
        // stake bonded nodes
        IXYOERC20(erc20).approveAndCall(consensus, total, methodData);

        emit BondStake(bondId, msg.sender, beneficiary, total);
    }

    function sendEthAndStake(bytes32 bondId, address payable beneficiary, address[] memory stakees, uint[] memory amounts) 
        public
        payable
    {
        if (msg.value > 0) {
            beneficiary.transfer(msg.value);
        }
        stake(bondId, beneficiary, stakees, amounts);
    }

    function isBondExpired(bytes32 bondId) 
        public 
        view 
        returns (bool)
    {
        return bondedStake[bondId].expirationSec < now;
    }
}