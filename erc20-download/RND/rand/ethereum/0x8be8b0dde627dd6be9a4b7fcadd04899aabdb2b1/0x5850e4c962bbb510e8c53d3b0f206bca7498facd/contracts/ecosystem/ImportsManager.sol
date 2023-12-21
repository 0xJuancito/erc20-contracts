// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IAddressRegistry.sol";

/// @title Rand.network Imports helper to manage all required import which is used in all tokenomics contracts
/// @author @adradr - Adrian Lenard
/// @notice Imports all required contracts
/// @dev Inherited by all ecosystem contracts

contract ImportsManager is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Access control roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant READER_ROLE = keccak256("READER_ROLE");

    // Registry update related variables
    event RegistryAddressUpdated(IAddressRegistry newAddress);
    IAddressRegistry public REGISTRY;

    function __ImportsManager_init() internal onlyInitializing {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Function to let Rand to update the address of the Safety Module
    /// @dev emits RegistryAddressUpdated() and only accessible by MultiSig
    /// @param newAddress where the new Safety Module contract is located
    function updateRegistryAddress(
        IAddressRegistry newAddress
    ) public whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        REGISTRY = newAddress;
        emit RegistryAddressUpdated(newAddress);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
