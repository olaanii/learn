// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract IdentityRegistry {
    mapping(address => bytes32) private identityHashes;
    mapping(bytes32 => address) private walletsByHash;

    event IdentityBound(address indexed wallet, bytes32 identityHash);

    function bindIdentity(address wallet, bytes32 identityHash) external {
        require(wallet != address(0), "invalid wallet");
        require(identityHash != bytes32(0), "invalid hash");
        require(identityHashes[wallet] == bytes32(0), "wallet already bound");
        require(walletsByHash[identityHash] == address(0), "hash already bound");

        identityHashes[wallet] = identityHash;
        walletsByHash[identityHash] = wallet;
        emit IdentityBound(wallet, identityHash);
    }

    function identityOf(address wallet) external view returns (bytes32) {
        return identityHashes[wallet];
    }

    function walletOf(bytes32 identityHash) external view returns (address) {
        return walletsByHash[identityHash];
    }
}
