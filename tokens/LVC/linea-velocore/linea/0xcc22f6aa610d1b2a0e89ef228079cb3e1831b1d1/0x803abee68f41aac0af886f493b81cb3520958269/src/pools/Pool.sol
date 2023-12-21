// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "src/lib/Token.sol";
import "src/lib/PoolBalanceLib.sol";
import "src/lib/UncheckedMemory.sol";
import "src/interfaces/IVault.sol";
import "src/interfaces/ISwap.sol";
import "src/interfaces/IAuthorizer.sol";
import "src/VaultStorage.sol";
import "./Satellite.sol";

/**
 * @dev a base contract for pools.
 *
 * - holds pool-specific slot of vault's storage as an immutable value.
 * - provides getters for the slot.
 *
 */
abstract contract Pool is IPool, Satellite {
    using PoolBalanceLib for PoolBalance;
    using UncheckedMemory for bytes32[];
    using UncheckedMemory for Token[];

    bytes32 immutable vaultStorageSlot;

    /**
     * @param selfAddr doesnt use address(this) because some pools upgradeable, in which case address(this) would be the implementation address.
     */
    constructor(IVault vault_, address selfAddr, address factory) Satellite(vault_, factory) {
        bytes32 slot = SSLOT_HYPERCORE_POOLBALANCES;
        assembly ("memory-safe") {
            mstore(0, selfAddr)
            mstore(32, slot)
            slot := keccak256(0, 64)
        }
        vaultStorageSlot = slot;
    }

    /**
     * pool balance is stored as two uint128; poolBalance and gaugeBalance.
     */

    function _getPoolBalance(Token token) internal view returns (uint256) {
        return PoolBalance.wrap(_readVaultStorage(_computeVaultStorageSlot(token))).poolHalf();
    }

    function _getGaugeBalance(Token token) internal view returns (uint256) {
        return PoolBalance.wrap(_readVaultStorage(_computeVaultStorageSlot(token))).gaugeHalf();
    }

    function _getPoolBalances(Token[] memory tokens) internal view returns (uint256[] memory ret2) {
        address vaultAddress = address(vault);
        uint256 tokenLength = tokens.length;
        bytes32[] memory ret = new bytes32[](tokenLength);
        unchecked {
            for (uint256 i = 0; i < tokenLength; ++i) {
                ret.u(i, _computeVaultStorageSlot(tokens.u(i)));
            }
            assembly ("memory-safe") {
                let len := mload(ret)
                mstore(ret, 0x0000000000000000000000000000000000000000000000000000000072656164)
                let success :=
                    staticcall(gas(), vaultAddress, add(ret, 28), add(4, mul(len, 32)), add(ret, 32), mul(32, len))
                if iszero(success) { revert(0, 0) }
                mstore(ret, len)
            }
            for (uint256 i = 0; i < tokenLength; ++i) {
                ret.u(i, bytes32(PoolBalance.wrap(ret.u(i)).poolHalf()));
            }
            assembly ("memory-safe") {
                ret2 := ret
            }
        }
    }

    /**
     * @return ret the storage slot for _poolBalances()[selfAddr][token]
     */
    function _computeVaultStorageSlot(Token token) internal view returns (bytes32 ret) {
        bytes32 vaultStorageSlot_ = vaultStorageSlot;
        assembly ("memory-safe") {
            mstore(0, token)
            mstore(32, vaultStorageSlot_)
            ret := keccak256(0, 64)
        }
    }

    function poolParams() external view virtual override returns (bytes memory) {
        return "";
    }
}
