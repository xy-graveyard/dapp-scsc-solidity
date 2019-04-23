pragma solidity >=0.5.0 <0.6.0;

import "../access/GovernorRole.sol";
import "./XyStakingConsensus.sol";
import "../utils/SafeMath.sol";
import "../token/ERC20/SafeERC20.sol";
import "../token/ERC20/IXYOERC20.sol";
import "../utils/Initializable.sol";

contract XyManagedEscrow is GovernorRole, Initializable {
    using SafeMath for uint;

    address erc20;
    address consensus;
    mapping (address => uint) escrowBalanceXYO;

    function initialize(
        address _token,
        address _consensusContract
    )
        initializer public
    {
        erc20 = _token;
        consensus = _consensusContract;
    }

    function deposit (uint xyoAmount) 
        public 
    {
        escrowBalanceXYO[msg.sender] = escrowBalanceXYO[msg.sender].add(xyoAmount);
        SafeERC20.transferFrom(erc20, msg.sender, address(this), xyoAmount);
    }

    function withdrawManagedEscrow (uint numXyo)
        public  
    {
        if (numXyo > 0) {
            require (escrowBalanceXYO[msg.sender] >= numXyo, "Not enough XYO");
            escrowBalanceXYO[msg.sender].sub(numXyo);
            SafeERC20.transfer(erc20, msg.sender, numXyo);
        }
    }

    function withdrawStake (bytes32 stakingId) 
        public  
        onlyGovernor
    {
        uint before = SafeERC20.balanceOf(erc20, address(this));
        XyStakingConsensus(consensus).withdrawStake(stakingId);
    
        uint aft = SafeERC20.balanceOf(erc20, address(this));
        escrowBalanceXYO[msg.sender] = escrowBalanceXYO[msg.sender].sub(aft.sub(before));
    }

    function sendEthAndManageStake(address payable beneficiary, address stakee, uint xyoAmount) 
        public
        payable
    {
        require(IXYOERC20(erc20).allowance(msg.sender, address(this)) >= xyoAmount, "Not enough allowance, make deposit");
        require(escrowBalanceXYO[msg.sender] >= xyoAmount, "Insufficient deposit");
        if (msg.value > 0) {
            beneficiary.transfer(msg.value);
        }
        bytes memory encoded = abi.encode(beneficiary, stakee);
        bytes memory methodData = abi.encode(4, encoded);
        IXYOERC20(erc20).approveAndCall(consensus, xyoAmount, methodData);
    }
}