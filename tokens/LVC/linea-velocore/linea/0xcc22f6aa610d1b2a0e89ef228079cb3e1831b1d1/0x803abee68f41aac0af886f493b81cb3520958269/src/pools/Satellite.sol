// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "src/interfaces/IVault.sol";

/**
 * @dev a base contract for peripheral contracts.
 *
 * 1. delegates access control to the vault
 * 2. use Diamond.yul's 'read' intrinsic function to read its storages
 *
 */
contract Satellite {
    IVault immutable vault;

    address immutable factory;

    constructor(IVault vault_, address factory_) {
        vault = vault_;
        factory = factory_;
    }

    modifier onlyVault() {
        require(msg.sender == address(vault), "only vault");
        _;
    }

    function _readVaultStorage(bytes32 slot) internal view returns (bytes32 ret) {
        address vaultAddress = address(vault);
        assembly ("memory-safe") {
            mstore(0, 0x7265616400000000000000000000000000000000000000000000000000000000)
            mstore(4, slot)
            let success := staticcall(gas(), vaultAddress, 0, 36, 0, 32)
            if iszero(success) { revert(0, 0) }
            ret := mload(0)
        }
    }

    modifier authenticate() {
        require(
            IAuthorizer(address(uint160(uint256(_readVaultStorage(SSLOT_HYPERCORE_AUTHORIZER))))).canPerform(
                keccak256(abi.encodePacked(bytes32(uint256(uint160(factory))), msg.sig)), msg.sender, address(this)
            ),
            "unauthorized"
        );
        _;
    }
}
