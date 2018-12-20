pragma solidity >=0.5.0 <0.6.0;
import '../XyStakingToken.sol';

contract XyStakingMock is XyStakingToken {

    constructor(XyERC20Token _token,
        ERC721 _stakableToken,
        uint _stakeCooldown,
        uint _unstakeCooldown)
        public
    XyStakingToken(_token, _stakableToken, _stakeCooldown, _unstakeCooldown)
    {

    }
     /** Increase and decrease cached stake amounts */
    function mock_updateCacheOnStake(uint amount, uint stakee) public {
      updateCacheOnStake(amount, stakee);
    }
    function mock_updateCacheOnActivate(uint amount, uint stakee) public {
      updateCacheOnActivate(amount, stakee);
    }
    function mock_updateCacheOnUnstake(uint amount, uint stakee) public {
        Stake memory data = Stake(
            amount,         // amount
            block.number,   // stakeBlock
            0,              // unstakeBlock
            stakee,         // stakee 
            true           // isActivated
        );
      updateCacheOnUnstake(data);
  }
    function mock_updateCacheOnWithdraw(uint amount, uint stakee) public {
      updateCacheOnWithdraw(amount, stakee);
   }
}