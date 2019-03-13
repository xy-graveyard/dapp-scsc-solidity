pragma solidity >=0.5.0 <0.6.0;
import "../XyStakingConsensus.sol";

contract XyConsensusMock is XyStakingConsensus {

    constructor(
        address[] memory stakees,
        address _token,
        address _stakableToken,
        address _governance)
        public
    XyStakingConsensus()
    {
      initialize(_token, _stakableToken, _governance);
      uint activeAmount = 1000;
      for (uint i = 0; i < stakees.length; i++) {
        updateCacheOnStake(activeAmount, stakees[i]);
        updateCacheOnActivate(activeAmount, stakees[i]);
      }

    }
    function mock_handleResponses(bytes32[] memory _requests, bytes memory responses)
        public 
        returns (uint)
    {
      return handleResponses(_requests, responses);
    }

    function mock_checkSigsAndStakes(
        bytes32 messageHash,
        address[] memory signers,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        uint8[] memory sigV
    )   
        view
        public 
        returns (uint)
    {
      checkSigsAndStakes(messageHash, signers, sigR, sigS, sigV);
    }
    function fake_updateCacheOnStake(uint amount, address stakee) public {
      updateCacheOnStake(amount, stakee);
    }
    function fake_updateCacheOnActivate(uint amount, address stakee) public {
      updateCacheOnActivate(amount, stakee);
    }
}