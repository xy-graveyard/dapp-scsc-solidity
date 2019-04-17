pragma solidity >=0.5.0 <0.6.0;

import "./XyERC20Token.sol";
import "../../utils/SafeMath.sol";

/**
 * @title ERC20Mintable
 * @dev ERC20 minting logic
 */
contract XyFaucet is XyERC20Token {
    using SafeMath for uint256;
    uint256 faucetDrip = 2000 ether;
    uint256 faucetCooldown = 480; // 2 hours
    address vault;
    mapping (address=>uint256) lastDripBlock;
    event NewDrip(address recipient);

    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) 
    XyERC20Token(initialSupply, tokenName, tokenSymbol)
    public
    {
        vault = msg.sender;
    }

    /**
     * @dev Faucet will mint tokens
     */
    function mint() public {
        require (lastDripBlock[msg.sender] == 0 || lastDripBlock[msg.sender].add(faucetCooldown) < block.number, "Cooling down");
        lastDripBlock[msg.sender] = block.number;
        _transfer(vault, msg.sender, faucetDrip);
        emit NewDrip(msg.sender);
    }
}
