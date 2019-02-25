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
      uint activeAmount = 1000;
      for (uint i = 0; i < stakees.length; i++) {
        uint stakee = uint(stakees[i]);
        updateCacheOnStake(activeAmount, stakee);
        updateCacheOnActivate(activeAmount, stakee);
      }

    }
    function mock_handleResponses(uint[] memory _requests, bytes memory responses)
        public 
        returns (uint)
    {
      return handleResponses(_requests, responses);
    }
    function mock_checkSigsAndStakes(
        uint messageHash,
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
    function fake_updateCacheOnStake(uint amount, uint stakee) public {
      updateCacheOnStake(amount, stakee);
    }
    function fake_updateCacheOnActivate(uint amount, uint stakee) public {
      updateCacheOnActivate(amount, stakee);
    }
}