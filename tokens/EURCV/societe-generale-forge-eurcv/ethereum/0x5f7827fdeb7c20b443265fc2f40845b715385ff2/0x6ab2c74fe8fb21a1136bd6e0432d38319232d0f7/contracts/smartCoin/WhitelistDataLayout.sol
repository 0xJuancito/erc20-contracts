// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.17;

/**
 * @dev This contract contains the storage part of the WhitelistUpgradeable contract.
 * It includes a __gap field that enables adding new fields without messing up the layout
 * and keeping compatibility accross UUPS updates (see field description for details)
 */
abstract contract WhitelistDataLayout {
    /**
     * @dev Structure containing all whitelisted addresses
     */
    mapping(address => bool) public whitelist;
    /**
     * @dev Address of the future new registrar operator
     */
    address internal newRegistrar;
    /**
     * @dev Address of the future new operations operator
     */
    address internal newOperations;
    /**
     * @dev Address of the future new technical operator
     */
    address internal newTechnical;
    /**
     * @dev Structure that keeps track of whether the future operators have accepted their future role
     */
    mapping(address => bool) internal hasAcceptedRole;
    /**
     * @dev Address of the future new implementation contract
     */
    address public newImplementation;
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[30] private __gap;
}
