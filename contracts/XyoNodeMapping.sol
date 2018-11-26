pragma solidity >=0.5.0 <0.6.0;

contract XyoNodeMapping {

    struct Node {
        address owner;
        address node;
        address next;
        uint stake;
    }

    address public head;
    uint public length = 0;
    mapping (address => Node) public nodes;

    constructor(
    )
        public
    {

    }

    function get(uint index 
    )
        public
        view
        returns(address)
    {
        require(index < length, "Index out of Range");
        uint i = index;
        address ptr = head;
        while (i != 0) {
            ptr = nodes[ptr].next;
            i = i - 1;
        }
        return ptr;
    }

    function add(address node
    )
        public
    {
        address ptr = tail();

        if (ptr == 0) {
            head = node;
        } else {
            nodes[ptr].next = node;
        }
        nodes[node].owner = msg.sender;
        nodes[node].node = node;
        length = length + 1;
    }

    function remove(address node
    )
        public
    {
        if (head == node) {
            head = nodes[head].next;
        } else {
            address ptr = head;
            while(ptr != 0) {
                if (nodes[ptr].next == node) {
                    nodes[ptr].next = nodes[nodes[ptr].next].next;
                    delete nodes[node];
                    length = length - 1;
                    return;
                } else {
                    ptr = nodes[ptr].next;
                }
            }
        }
    }

    function tail(
    )
        public
        view
        returns(address)
    {
        address ptr = head;
        while (nodes[ptr].next != 0) {
            ptr = nodes[ptr].next;
        }
        return ptr;
    }

}
