pragma solidity >=0.5.0 <0.6.0;
import "../staking/XyStakingModel.sol";

contract XyStakingMock is XyStakingModel {
  Stake public tempStake;
    constructor(address _token,
        address _stakableToken,
        address _governance)
        public
    // XyStakingModel(_token, _stakableToken, _governance)
    XyStakingModel()
    {
      init(_token, _stakableToken, _governance);
    }

    function fake_data(uint amount, address stakee) internal view returns (Stake memory) {
      Stake memory data = Stake(
          amount,         // amount
          block.number,   // stakeBlock
          0,              // unstakeBlock
          stakee,         // stakee 
          msg.sender,     // staker
          true,          // isActivated
          false           // is coolded down
      );
      return data;
    }
     /** Increase and decrease cached stake amounts */
    function fake_updateCacheOnStake(uint amount, address stakee) public {
      updateCacheOnStake(fake_data(amount, stakee));
    }
    function fake_updateCacheOnActivate(uint amount, address stakee) public {
      updateCacheOnActivate(fake_data(amount, stakee));
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
      tempStake = data;
      updateCacheOnUnstake(tempStake);
  }
    function fake_updateCacheOnWithdraw(uint amount, address stakee) public {
      updateCacheOnWithdraw(fake_data(amount, stakee));
   }
}