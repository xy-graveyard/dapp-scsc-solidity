pragma solidity >=0.5.0 <0.6.0;

import "./token/ERC721/ERC721Enumerable.sol";
import "./ECDSA.sol";

/* 
    Contract used to track ownership of stakable components in XYO network using 
    transferable NFTs
*/
contract XyStakableToken is ERC721Enumerable {
    using ECDSA for bytes32;

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
}