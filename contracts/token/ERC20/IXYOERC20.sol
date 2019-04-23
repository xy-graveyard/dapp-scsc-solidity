pragma solidity >=0.5.0 <0.6.0;

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IXYOERC20 {
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) external returns (bool success);

    function allowance(address owner, address spender) external view returns (uint256);
}
