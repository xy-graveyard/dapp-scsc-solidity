pragma solidity >=0.5.0 <0.6.0;
import '../XyStakingConsensus.sol';

contract XyConsensusMock is XyStakingConsensus {

    constructor(
        address[] memory stakees,
        address _token,
        address _stakableToken,
        address _governance)
        public
    XyStakingConsensus(_token, _stakableToken, _governance)
    {
      uint activeAmount = 1000;
      for (uint i = 0; i < stakees.length; i++) {
        uint stakee = uint(stakees[i]);
        updateCacheOnStake(activeAmount, stakee);
        updateCacheOnActivate(activeAmount, stakee);
      }

    }

}