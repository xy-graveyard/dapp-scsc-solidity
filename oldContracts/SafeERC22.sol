pragma solidity >=0.5.0 <0.6.0;

import "./IERC20.sol";
import "../../SafeMath.sol";
import "../../utils/Address.sol";
/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
  using Address for address;

  function safeTransfer(
    IERC20 token,
    address to,
    uint256 value
  )
    internal
  {
    require(token.transfer(to, value));
  }

  function safeTransferFrom(
    IERC20 token,
    address from,
    address to,
    uint256 value
  )
    internal
  {
    require(token.transferFrom(from, to, value));
  }

  function safeApprove(
    IERC20 token,
    address spender,
    uint256 value
  )
    internal
  {
    require(token.approve(spender, value));
  }

  event _Log(uint dataSize);
  function handleReturnBool() internal returns(bool result) {
    // solium-disable-next-line security/no-inline-assembly
    uint dataSize = 0;

    assembly {
      dataSize := add(dataSize, returndatasize())
      switch returndatasize()
      case 0 { // not a std erc20
        result := 1
      }
      case 32 { // std erc20
        returndatacopy(0, 0, 32)
        result := mload(0)
      }
      default { // anything else, should revert for safety
        result := 1

        // revert(0, 0)
      }
    }
    emit _Log(dataSize);

  }

  function asmTransfer(address _token, address _to, uint256 _value) internal returns(bool) {
    require(_token.isContract());
    // solium-disable-next-line security/no-low-level-calls
    (bool success, ) = _token.call(abi.encodeWithSignature("transfer(address,uint256)", _to, _value));
    // require(success, "Transfer proxy fail");\
    emit _Log(success ? 1 : 0);

    return handleReturnBool();
  }

  function asmTransferFrom(address _token, address _from, address _to, uint256 _value) internal returns(bool) {
    require(_token.isContract());
    // solium-disable-next-line security/no-low-level-calls

    (bool success, ) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, _to, _value));

    return handleReturnBool();
  }

}