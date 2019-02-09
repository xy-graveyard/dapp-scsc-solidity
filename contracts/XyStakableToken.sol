pragma solidity >=0.5.0 <0.6.0;

import "./token/ERC721/ERC721Enumerable.sol";
import "./ECDSA.sol";

/* 
    Contract used to track ownership of stakable components in XYO network using 
    transferable NFTs
*/
contract XyStakableToken is ERC721Enumerable {
    using ECDSA for bytes32;
    address public governer;

    uint[] public blockProducers;
    mapping(uint => uint) public blockProducerIndexes;

    constructor (
        address _governer
    ) 
        public
    {
        governer = _governer;
    }

    /** 
        Mints a component with signed datagram from the ownee device/component that authorized its ownership
        Emits transfer event to sender
        @param ownee - device to be owned by sender
        @param sigR - the R param of the sig
        @param sigS - the S param of the sig
        @param sigV - the V param of the sig
    */
    function mint(address ownee, 
                    bytes32 sigR,
                    bytes32 sigS,
                    uint8 sigV,
                    bool isBlockProducer) 
        public 
    {
        bytes32 data = _encodeData(ownee);
        address signer = ecrecover(data, sigV, sigR, sigS);
        require(ownee == signer, "Invalid Signature");
        uint component = uint(ownee);
        if (isBlockProducer) {
            blockProducerIndexes[component] = blockProducers.length;
            blockProducers.push(component);
        }
        _mint(msg.sender, component);
    }

    /**
        Only govenor (the scsc) can burn a token
        if blockProducer, delete from blockProducer listing
        @param stakee the stakee to burn 
    */
    function burn(uint stakee) public {
        require(msg.sender == governer);
        uint index = blockProducerIndexes[stakee];
        if (index != 0) {
            uint lastDivinerIndex = blockProducers.length - 1;
            uint lastDiviner = blockProducers[lastDivinerIndex];

            blockProducers[lastDivinerIndex] = 0;
            blockProducers.length--;
            delete blockProducerIndexes[stakee];
            
            blockProducers[index] = lastDiviner;
            blockProducerIndexes[lastDiviner] = index;
        }
        _burn(ownerOf(stakee), stakee);
    }

    /**
        @dev Builds a prefixed hash to mimic the behavior of eth_sign
        @param _hash bytes32 Message hash to be prefixed
    */
    function prefixed(bytes32 _hash)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash));
    }

    function isBlockProducer(uint stakee) public view returns (bool) {
        return stakee == blockProducers[blockProducerIndexes[stakee]];
    }

    function numBlockProducers() public view returns (uint) {
        return blockProducers.length;
    }

    function _encodeData(address ownee) private view returns (bytes32) {
        require(ownee != address(0), "Missing Ownee");
        bytes memory m = abi.encodePacked(ownee, msg.sender);
        return prefixed(keccak256(m));
    }
}