pragma solidity >=0.5.0 <0.6.0;

import "./XySignedData.sol";

/*

Deployments 
==============
Kovan = 0x89AAbf18d6030FB1a78B9B609531021599d21506

*/

contract XyAddressOwnership {

    using XySignedData for XySignedData;

    struct Ownership {
        address owner;
        uint index;
    }

    mapping (address => Ownership) public owners;

    constructor(
    )
        public
    {

    }

    /* set the owner of the calling account */
    function setOwner(address owner)
        public
    {
        owners[msg.sender].index = owners[msg.sender].index + 1;
        owners[msg.sender].owner = owner;
    }

    /* set the owner using a signed datagram from the ownee */
    /* the ownee must have signed the datagram toprove that they want to be owned */
    /* the datagram contains the ownee and owner addresses and an index that is one larger then
        the previous address to prove that this is a new request, initial one = 0 */
    function setOwnerWithProxy(
        address ownee,
        address owner,
        uint index,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    )
        public
        returns(bool)
    {
        require(ownee != address(0), "Missing Ownee");
        require(owner != address(0), "Missing Ownee");
        require(index == owners[ownee].index + 1, "Invalid Index");
        require(owner != address(0), "Missing Ownee");

        bytes memory data = abi.encodePacked(ownee, owner, index);
        address signer = XySignedData.getAddressOfSigner(data, sigV, sigR, sigS);
        
        require(ownee == signer, "Invalid Signature");

        //record the change in ownership
        owners[ownee].index = index;
        owners[ownee].owner = owner;

        return true;
    }
}