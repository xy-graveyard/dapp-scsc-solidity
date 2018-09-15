pragma solidity ^0.4.24;

import "./Ownable.sol";
import "./ERC20.sol";

import "./XyoNodeMapping.sol";

/**
 * @title XyoStakedConsensus
 * @dev Manages the Stake for multiple clients in a decentralized consensus system
 */
contract XyoStaked is Ownable, XyoNodeMapping {

  struct Request {
    address node;
    uint amount;
    uint time;
  }

  event Claim (
    address owner,
    address node
  );

  event Stake (
    address node,
    uint amount
  );

  mapping(address => address) public nodeOwners; //Lists the owners of the nodes

  Request[] public stakeRequests; //List of Stake Requests
  function getStakeRequestsLen() public view returns(uint) {
    return stakeRequests.length;
  }

  Request[] public unstakeRequests; //List of Unstake Requests
  function getUnstakeRequestsLen() public view returns(uint) {
    return unstakeRequests.length;
  }

  ERC20 public token; //address of the ERC20 token used for staking
  uint public cooldown; //the amount of time required for withdrawn stake to be available to be withdrawn

  /**
  * @dev The constructor sets the rules for the system that can not be changed ever again.
  * @param _token - The address of the ERC20 token to be used for staking
  * @param _cooldown - The time delay before a stake is available for withdrawal ater a remove
  */
  constructor(
    address _token,
    uint _cooldown
  )
    public
  {
    token = ERC20(_token);
    cooldown = _cooldown;
  }

  /**
   * @dev Claim a Node to an Owner. Requires a signed datagram from the node containing the owner address
   * @param node - The node's address.  The signature should be of this address concated with the owner's address sha256 hashed
   * @param v - The v component of the signature
   * @param r - The r component of the signature
   * @param s - The s component of the signature
   */
  function claim(
    address node,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    public
  {
    bytes32 hashValue = keccak256(abi.encodePacked(msg.sender, node));

    address realAddress = ecrecover(hashValue, v, r, s);
    emit Claim(msg.sender, node);
    require (realAddress == node);
    nodeOwners[node] = msg.sender;
    add(node);
  }

  /**
   * @dev Adds Stake to a specific Node in the system
   * @param node - The node on the XYO network that the stake is for
   * @param amount - The amount of XYO being added to the stake
   * @return The total XYO staked for this node
   */
  function stake(
    address node,
    uint amount
  )
    public
  {
    require(nodes[node].owner == msg.sender);

    //we assume that the caller gave this contract permission to transfer tokens before this call
    token.transferFrom(msg.sender, this, amount);
    stakeRequests.push(Request(node, amount, now));
    emit Stake(node, amount);
  }

  /**
   * @dev Removes Stake from a specific Node in the system
   * @dev This Stake is not available to be withdrawn until cooldown time has expired
   * @param node - The node on the XYO network that the stake is for
   * @param amount - The amount of XYO being added to the stake
   * @return The total XYO staked for this node
   */
  function unstake(
    address node,
    uint amount
  )
    public
  {
    require(nodes[node].owner == msg.sender);
    require(nodes[node].stake >= amount);
    nodes[node].stake = nodes[node].stake - amount;
    unstakeRequests.push(Request(node, amount, now));
  }

  function process(
  )
    public
    returns (uint)
  {
    uint count = 0;
    for (uint i = 0; i < stakeRequests.length; i++) {
      if (nodes[stakeRequests[i].node].owner == owner) {
        if ((stakeRequests[i].time + cooldown) < now) {
          nodes[stakeRequests[i].node].stake = nodes[stakeRequests[i].node].stake + stakeRequests[i].amount;
          stakeRequests[i].amount = 0;
          count = count + 1;
        }
      }
    }
    purgeEmptyStakeRequests();
    return count;
  }

  /**
   * @dev Withdraws Stake
   * @return The total XYO that may be withdrawn from this node after this transaction
   */
  function withdraw(
  )
    public
    returns (uint)
  {
    uint total = 0;
    for (uint i = 0; i < unstakeRequests.length; i++) {
      if (nodes[unstakeRequests[i].node].owner == owner) {
        if ((unstakeRequests[i].time + cooldown) < now) {
          total = total + withdrawFromRequest(unstakeRequests[i]);
        }
      }
    }
    purgeEmptyUnstakeRequests();
    return total;
  }

  function purgeEmptyStakeRequests(
  )
    private
  {
    uint index = 0;
    while (index < stakeRequests.length) {
      if (stakeRequests[index].amount == 0) {
        stakeRequests[index] = stakeRequests[stakeRequests.length - 1];
        delete stakeRequests[stakeRequests.length - 1];
      } else {
        index++;
      }
    }
  }

  function purgeEmptyUnstakeRequests(
  )
    private
  {
    uint index = 0;
    while (index < unstakeRequests.length) {
      if (unstakeRequests[index].amount == 0) {
        unstakeRequests[index] = unstakeRequests[unstakeRequests.length - 1];
        delete unstakeRequests[unstakeRequests.length - 1];
      } else {
        index++;
      }
    }
  }

  function withdrawFromRequest(
    Request request
  )
    private
    returns (uint)
  {
    require(nodes[request.node].owner == msg.sender);
    require((request.time + cooldown) < now);
    token.transferFrom(this, msg.sender, request.amount);
    request.amount = 0;
  }

  /**
   * @dev Determines the amount of stake that can be withdrawn from a node
   * @param owner - The owner address of the items to to check for availability
   * @return The total XYO that may be withdrawn from this node
   */
  function availableToWithdraw(address owner)
    public
    view
    returns (uint)
  {
    uint available = 0;
    for (uint i = 0; i < unstakeRequests.length; i++) {
      if (nodes[unstakeRequests[i].node].owner == owner) {
        if ((unstakeRequests[i].time + cooldown) < now) {
          available = available + unstakeRequests[i].amount;
        }
      }
    }
    return available;
  }

}
