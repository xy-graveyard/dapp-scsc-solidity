pragma solidity >=0.5.0 <0.6.0;

library XyoSignedData {

    function getAddressOfSigner(
        bytes memory data,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    )
    internal
    pure
    returns (address)
    {
        bytes32 hashValue = keccak256(data);
        return ecrecover(hashValue, sigV, sigR, sigS);
    }
}