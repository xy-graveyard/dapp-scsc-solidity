pragma solidity >=0.5.0 <0.6.0;

import "./Roles.sol";

contract GovernorRole {

  using Roles for Roles.Role;
  Roles.Role private governors;

  event GovernorAdded(address indexed account);
  event GovernorRemoved(address indexed account);

  function init() 
     internal
  {
    _addGovernor(msg.sender);
  }

  modifier onlyGovernor() {
    require(isGovernor(msg.sender), "Only Governor Action");
    _;
  }

  function isGovernor(address account) public view returns (bool) {
    return governors.has(account);
  }

  function addGovernor(address account) public onlyGovernor {
    _addGovernor(account);
  }

  function renounceGovernor() public {
    _removeGovernor(msg.sender);
  }

  function _addGovernor(address account) internal {
    governors.add(account);
    emit GovernorAdded(account);
  }

  function _removeGovernor(address account) internal {
    governors.remove(account);
    emit GovernorRemoved(account);
  }
  
}
