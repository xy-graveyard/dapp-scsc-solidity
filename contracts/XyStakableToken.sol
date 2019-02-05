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
                    uint8 sigV) 
        public 
    {
        require(ownee != address(0), "Missing Ownee");
        bytes memory m = abi.encodePacked(ownee, msg.sender);
        bytes32 data = prefixed(keccak256(m));
        address signer = ecrecover(data, sigV, sigR, sigS);
        require(ownee == signer, "Invalid Signature");
        _mint(msg.sender, uint(ownee));
    }

    function burn(uint stakee) public {
        require(msg.sender == governer);
        _burn(ownerOf(stakee), stakee);
    }

    /**
        Allow submitting a signed message instead of the signature
    */
    function mintWithMessage(address ownee, 
                    bytes memory signedMessage) 
        public 
    {
        require(ownee != address(0), "Missing Ownee");
        bytes memory m = abi.encodePacked(ownee, msg.sender);
        bytes32 data = prefixed(keccak256(m));
        address signer = data.recover(signedMessage);
        require(ownee == signer, "Invalid Signature");
        _mint(msg.sender, uint(ownee));
    }

    /**
        @dev Builds a prefixed hash to mimic the behavior of eth_sign
        @param _hash bytes32 Message hash to be prefixed
    */
    function prefixed(bytes32 _hash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash));
    }

    function toBytes(address a) public pure returns (bytes memory b){
   assembly {
        let m := mload(0x40)
        mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
        mstore(0x40, add(m, 52))
        b := m
   }
}
    event TestResults(bool[] results);
    event Testing(uint resultlen);

    uint256[] storageResults;

    /** 
        Test many signatures
    */
    function testMany( bytes32 data,
                        address[] memory checkAddresses,
                        bytes32[] memory sigR,
                        bytes32[] memory sigS,
                        uint8[] memory sigV) 
        public 
        returns (bool[] memory)
    {
        bool[] memory results = new bool[](checkAddresses.length);

        for (uint i = 0; i < checkAddresses.length; i++) {
            address signer = ecrecover(prefixed(data), sigV[i], sigR[i], sigS[i]);
            results[i] = (checkAddresses[i] == signer);
            storageResults.push(results[i] ? 1: 0); // TODO Simulate real contract call...
        }
        return results;
    }
}