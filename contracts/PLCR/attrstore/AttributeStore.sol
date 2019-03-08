pragma solidity >=0.5.0 <0.6.0;

library AttributeStore {
    struct Data {
        mapping(bytes32 => uint) store;
    }

    function getAttribute(Data storage self, bytes32 _UUID, string memory _attrName)
    internal view returns (uint) {
        bytes32 key = keccak256(abi.encodePacked(_UUID, _attrName));
        return self.store[key];
    }

    function setAttribute(Data storage self, bytes32 _UUID, string memory _attrName, uint _attrVal)
    internal {
        bytes32 key = keccak256(abi.encodePacked(_UUID, _attrName));
        self.store[key] = _attrVal;
    }
}
