pragma solidity >=0.5.0 <0.6.0;
import "../staking/XyStakingConsensus.sol";
import "../XyPayOnDelivery.sol";

contract XyConsensusMock is XyStakingConsensus {
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
    constructor(
        address[] memory stakees)
        public
        XyStakingConsensus()
    {
      uint activeAmount = 1000;
      for (uint i = 0; i < stakees.length; i++) {
        Stake memory data = fake_data(activeAmount, stakees[i]);
        updateCacheOnStake(data);
        updateCacheOnActivate(data);
      }
    }
 

   
    function fake_updateCacheOnStake(uint amount, address stakee) public {
      updateCacheOnStake(fake_data(amount, stakee));
    }
    function fake_updateCacheOnActivate(uint amount, address stakee) public {
      updateCacheOnActivate(fake_data(amount, stakee));
    }
    function submitResponse(
        bytes32 requestId, 
        uint8 requestType, 
        bytes memory responseData,
        address pOnDAddress
    ) 
        public
        payable
    {
       XyPayOnDelivery(pOnDAddress).submitResponse(requestId,requestType,responseData);
    }
}