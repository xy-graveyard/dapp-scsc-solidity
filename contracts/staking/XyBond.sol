pragma solidity >=0.5.0 <0.6.0;

import "./XyStakingConsensus.sol";
import "../utils/SafeMath.sol";
import "../token/ERC20/SafeERC20.sol";
import "../token/ERC20/IXYOERC20.sol";
import "../utils/Initializable.sol";
import "../access/GovernorRole.sol";

contract XyBond is GovernorRole, Initializable {
    using SafeMath for uint;

    address public erc20;
    address public consensus;
    uint public governablePeriod; // seconds after bond creation it's governable
    mapping (bytes32 => address) public stakeIdManager;

    event BondDeposit(bytes32 bondId, address beneficiary, uint amount, uint expiration);
    event BondWithdraw(bytes32 bondId, address beneficiary, uint amount);
    event BondStake(bytes32 bondId, address sender, address beneficiary, uint amount);
    event BondUnstake(bytes32 bondId, address sender, bytes32 stakingId, uint amount);

    struct Bond {
        uint value;             // amount staked
        uint expirationSec;     // expiration date in seconds
        uint creationSec;       // creation date in seconds
        uint allocated;         // number allocated to node stake
        address owner;          // who owns the stake
        uint8 interest;         // possibly add interest or relationship here
    }

    mapping (bytes32 => Bond) public bond;
    mapping (bytes32 => uint) public bondIndex;
    mapping (address => bytes32[]) public ownerBonds;
    bytes32[] public bonds;

    function initialize (
        address _token,
        address _consensusContract,
        uint _governablePeriod
    )
        initializer 
        public
    {
        erc20 = _token;
        consensus = _consensusContract;
        governablePeriod = _governablePeriod;
        super.init();
    }

    /**
        Must approve before deposit can transfer in token
    */
    function deposit (uint xyoAmount, uint expirationDate) 
        public 
        returns (bytes32)
    {
        return depositTo(msg.sender, xyoAmount, expirationDate);
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
        returns (bytes32)
    {
        require (expirationDate > now, "Expiry must be in the future");
        bytes32 bondId = keccak256(abi.encode(to, xyoAmount, expirationDate, block.number));
        Bond memory ns = Bond(
            xyoAmount,
            expirationDate,
            block.timestamp,
            0,
            to,
            0
        );
        bondIndex[bondId] = bonds.length;
        bond[bondId] = ns;
        ownerBonds[to].push(bondId);
        bonds.push(bondId);
        
        SafeERC20.transferFrom(erc20, to, address(this), xyoAmount);
        emit BondDeposit(bondId, to, xyoAmount, expirationDate);
        return bondId;
    }

    function withdrawTo (bytes32 bondId, address to) 
        public
    {
        Bond storage bs = bond[bondId];
        uint withdrawAmount = bs.value;
        require (withdrawAmount > 0, "Bond has no value");
        bs.value = 0; // erase value of bond
        bool isOwner = msg.sender == bs.owner;
        require (bs.allocated == 0, "Bond must have no allocated stake");
        require (isOwner || governable(bs), "owner or governable can withdraw");
        if (isOwner) {
            require (now > bs.expirationSec, "Bond is still active");
        }
        SafeERC20.transfer(erc20, to, withdrawAmount);

        emit BondWithdraw(bondId, to, withdrawAmount);
    }

    function stake (bytes32 bondId, address payable beneficiary, address[] memory stakees, uint[] memory amounts)
        public
    {
        Bond storage bs = bond[bondId];
        bool isOwner = msg.sender == bs.owner;
        require (isOwner || governable(bs), "owner or governable can stake");
        
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

    function unstake (bytes32 bondId, bytes32 stakingId) 
        public  
    {
        bytes32 checkBondId = XyStakingConsensus(consensus).bondedStake(stakingId);
        (uint amount,,,,,,) = XyStakingConsensus(consensus).stakeData(stakingId);
        require(checkBondId == bondId, "Stake needs to be bonded");

        Bond storage bs = bond[bondId];
        require (msg.sender == bs.owner || governable(bs), "owner or governable can unstake");
        
        require(bs.allocated >= amount, "Cannot unstake over bond allocation");
        bs.allocated = bs.allocated.sub(amount);

        // will fail if already withdrew  
        XyStakingConsensus(consensus).unstakeBonded(bondId, stakingId);

        emit BondUnstake(bondId, msg.sender, stakingId, amount);
    }

    function isExpired(bytes32 bondId) 
        public 
        view 
        returns (bool)
    {
        return bond[bondId].expirationSec < now;
    }

    function governable(Bond memory bs) 
        private 
        view
        returns (bool) 
    {
        bool isGov = isGovernor(msg.sender);
        bool govActive = now <= bs.creationSec.add(governablePeriod);
        return isGov && govActive;
    }
}