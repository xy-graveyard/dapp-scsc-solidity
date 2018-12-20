pragma solidity >=0.5.0 <0.6.0;

import "./XyStaked.sol";

  /**
  * @title XyoStakedConsensus
  * @dev Manages the Stake for multiple clients in a decentralized consensus system
  */
contract XyStakedConsensus is XyStaked {

    struct Block {
        uint previousBlock;
        uint ipfsHash;
        address creator;
    }

    struct Challenge {
        uint block;
        address challenger;
    }

    uint genesis;
    uint current;

    mapping(uint => Block) public blocks; //The blocks in the chain
    mapping(uint => Challenge) public challenges; //The blocks in the chain

    /**
    * @dev The constructor sets the rules for the system that can not be changed ever again.
    * @param _token - The address of the ERC20 token to be used for staking
    * @param _cooldown - The time delay before a stake is available for withdrawal after a remove
    * @param _genesis - The genesis block of the chain being staked
    */
    constructor(
      address _token,
      uint _cooldown,
      uint _genesis
    )
        public
        XyStaked(_token, _cooldown)
    {
        genesis = _genesis;
        current = _genesis;
    }

    function challenge(
        uint blockToChallenge
    )
      public
    {
        challenges[blockToChallenge] = Challenge(blockToChallenge, msg.sender);
    }

}
