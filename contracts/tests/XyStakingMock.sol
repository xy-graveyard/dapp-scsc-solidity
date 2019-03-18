pragma solidity >=0.5.0 <0.6.0;
import "../XyStakingModel.sol";

contract XyStakingMock is XyStakingModel {

    constructor(address _token,
        address _stakableToken,
        address _governance)
        public
    // XyStakingModel(_token, _stakableToken, _governance)
    XyStakingModel()
    {
      init(_token, _stakableToken, _governance);
    }
     /** Increase and decrease cached stake amounts */
    function fake_updateCacheOnStake(uint amount, address stakee) public {
      updateCacheOnStake(amount, stakee);
    }
    function fake_updateCacheOnActivate(uint amount, address stakee) public {
      updateCacheOnActivate(amount, stakee);
    }
    function stub_updateCacheOnUnstake(uint amount, address stakee) public {
        Stake memory data = Stake(
            amount,         // amount
            block.number,   // stakeBlock
            0,              // unstakeBlock
            stakee,         // stakee 
            msg.sender,     // staker
            true,          // isActivated
            false           // is coolded down
        );
      updateCacheOnUnstake(data);
  }
    function fake_updateCacheOnWithdraw(uint amount, address stakee) public {
      updateCacheOnWithdraw(amount, stakee);
   }
}