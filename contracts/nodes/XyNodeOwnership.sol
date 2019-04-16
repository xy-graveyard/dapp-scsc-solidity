pragma solidity >=0.5.0 <0.6.0;

import "./XyNode.sol";

/* 
    Contract used to track stakable addresses in XYO network 
    These node ids are the payment ids that are passed up the XYO origin chains
    Stakers on these nodes may make reward withdrawels,
*/
contract XyNodeOwnership is XyNode {

    // Mapping from owner to list of owned node IDs
    mapping(address => address[]) private _ownedNodes;

    // Mapping from node address to index of the owner nodes list
    mapping(address => uint256) private _ownedNodesIndex;

    /**
        * @dev Gets the node ID at a given index of the nodes list of the requested owner
        * @param owner address owning the nodes list to be accessed
        * @param index uint256 representing the index to be accessed of the requested nodes list
        * @return uint256 node ID at the given index of the nodes list owned by the requested address
    */
    function nodeOfOwnerByIndex(
        address owner,
        uint256 index
    )
        public
        view
        returns (address)
    {
        require(index < numNodesOwned(owner));
        return _ownedNodes[owner][index];
    }

    /**
    * @dev Internal function to mint a new node
    * Reverts if the given node already exists
    * @param to address the beneficiary that will own the minted node
    * @param node address of the node to be minted by the msg.sender
    */
    function create(address to, address node, uint8 t) public {

        super._create(to, node, t);

        uint256 length = _ownedNodes[to].length;
        _ownedNodes[to].push(node);
        _ownedNodesIndex[node] = length;
    }

    function createMany(address to, address[] memory nodes, uint8[] memory t) public {
        require(nodes.length == t.length, "Must supply correct nodes and types");
        for (uint i = 0; i < nodes.length; i++) {
            create(to, nodes[i], t[i]);
        }
    }

    function removeMany(address owner, address[] memory nodes) public {
        for (uint i = 0; i < nodes.length; i++) {
            remove(owner, nodes[i]);
        }
    }

    /**
    * @dev Internal function to burn a specific node
    * Reverts if the node does not exist
    * @param owner owner of the node to burn
    * @param node address of the node being burned by the msg.sender
    */
    function remove(address owner, address node) public {
        super._remove(owner, node);

        // To prevent a gap in the array, we store the last node in the index of the node to delete, and
        // then delete the last slot.
        uint256 nodeIndex = _ownedNodesIndex[node];
        uint256 lastNodeIndex = _ownedNodes[owner].length.sub(1);
        address lastNode = _ownedNodes[owner][lastNodeIndex];

        _ownedNodes[owner][nodeIndex] = lastNode;
        // This also deletes the contents at the last position of the array
        _ownedNodes[owner].length--;

        // Note that this will handle single-element arrays. In that case, both nodeIndex and lastNodeIndex are going to
        // be zero. Then we can make sure that we will remove node from the ownedNodes list since we are first swapping
        // the lastNode to the first position, and then dropping the element placed in the last position of the list

        _ownedNodesIndex[node] = 0;
        _ownedNodesIndex[lastNode] = nodeIndex;
    }

    /**
    * @dev Gets the balance of the specified address
    * @param owner address to query the balance of
    * @return uint256 representing the amount owned by the passed address
    */
    function numNodesOwned(address owner) public view returns (uint256) {
        require(owner != address(0));
        return _ownedNodes[owner].length;
    }
}