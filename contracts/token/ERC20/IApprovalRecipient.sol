pragma solidity >=0.5.0 <0.6.0;

interface ApprovalRecipient { 
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external; 
}
