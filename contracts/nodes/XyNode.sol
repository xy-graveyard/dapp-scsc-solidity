pragma solidity >=0.5.0 <0.6.0;

import "../utils/Initializable.sol";
import "../access/GovernorRole.sol";
import "../utils/SafeMath.sol";

/* 
    Contract used to track stakable addresses in XYO network 
    These node ids are the payment ids that are passed up the XYO origin chains
    Stakers on these nodes may make reward withdrawels,
*/
contract XyNode is Initializable, GovernorRole {
    using SafeMath for uint;

    enum NodeType { Diviner, Bridge, Archivist, Sentinel }

    event NodeCreated (
        address owner,
        address node,
        address creator,
        uint8 nodeType
    );

    event NodeRemoved(
        address owner,
        address node,
        address creator,
        uint8 nodeType
    );

    // Mapping from node ID to owner
    mapping (address => address) public nodeOwner;

    // Add mapping of indexes so that we can find a node by their nodes[index[id]]
    mapping (uint8 => address[]) public nodesByType;
    mapping (address => uint) public nodeIndexes;
    mapping (address => uint8) nodeType;

    uint8 numTypes = 4;

    function initialize () 
        initializer public
    {
        super.init();
    }

    /** 
        Mints a stakable address with the account hash as the node id
        Emits transfer event to sender
        msg.sender - new account creator
    */
    function _create(address to, address node, uint8 t) 
        internal
    {
        require(nodeOwner[node] == address(0), "This node exists");
        nodeOwner[node] = to;

        require(isGovernor(msg.sender) || msg.sender == to, "Only owner or governor can create");
        nodeIndexes[node] = numNodes(t);
        nodesByType[t].push(node);
        nodeType[node] = t;
        emit NodeCreated(to, node, msg.sender, t);
    }

    /**
        Only govenor (the scsc) can burn a BP (because stake needs to be removed)
        @param node the stakee to burn 
    */
    function _remove(address owner, address node)
        internal 
    {
        require(ownerOf(node) == owner);
        nodeOwner[node] = address(0);
        require(isGovernor(msg.sender) || msg.sender == node, "Only sender or governor can create");
        uint8 t = nodeType[node];
        uint lastnodeIndex = numNodes(t) - 1;
        uint index = nodeIndexes[node];
        address lastnode = nodesByType[t][lastnodeIndex];

        nodesByType[t][lastnodeIndex] = address(0);
        nodesByType[t].length--;
        delete nodeIndexes[node];
        delete nodeType[node];
        
        nodesByType[t][index] = lastnode;
        nodeIndexes[lastnode] = index;
        emit NodeRemoved(owner, node, msg.sender, t);
    }

    function ownerOf(address node) public view returns (address owner) {
        owner = nodeOwner[node];
        require(owner != address(0));
    }
    /**
        Expose internal exists function to be used
    */
    function exists(address node) public view returns (bool) {
        return nodeOwner[node] != address(0);
    }

    function numNodes(uint8 t) public view returns (uint) {
        return nodesByType[t].length;
    }

    /**
    * @dev Gets the node ID at a given index of all the nodes in this contract
    * Reverts if the index is greater or equal to the total number of nodes
    * @param index uint256 representing the index to be accessed of the nodes list
    * @return uint256 node ID at the given index of the nodes list
    */
    function nodeByIndex(uint256 index, uint8 t) public view returns (address) {
        require(index < numNodes(t));
        return nodesByType[t][index];
    }

    function totalSupply() public view returns (uint) {
        uint supply = 0;
        for (uint8 i = 0; i < numTypes; i++) {
            supply = supply.add(numNodes(i));
        }
        return supply;
    }
}