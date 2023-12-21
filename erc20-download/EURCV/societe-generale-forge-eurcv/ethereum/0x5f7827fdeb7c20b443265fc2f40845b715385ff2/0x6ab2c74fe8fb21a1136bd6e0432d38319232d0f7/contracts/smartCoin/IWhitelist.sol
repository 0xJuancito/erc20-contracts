// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.17;

interface IWhitelist {
    /**
     * @dev Emitted when an address is added to the whitelist
     */
    event WhitelistedAddressAdded(address addr);
    /**
     * @dev Emitted when an address is removed from the whitelist
     */
    event WhitelistedAddressRemoved(address addr);
    /**
     * @dev Emitted when new operators are named by the registrar operator
     */
    event NamedNewOperators(
        address registrar,
        address operations,
        address technical
    );
    /**
     * @dev Emitted when the future new registrar operator has accepted the role
     */
    event AcceptedRegistrarRole(address registrar);
    /**
     * @dev Emitted when the future new operations operator has accepted the role
     */
    event AcceptedOperationsRole(address operations);
    /**
     * @dev Emitted when the future new technical operator has accepted the role
     */
    event AcceptedTechnicalRole(address technical);
    /**
     * @dev Emitted when the future new implementation contract has been authorized by the registrar
     */
    event ImplementationAuthorized(address implementation);

    /**
     * @dev Adds `holder` address to the whitelist
     */
    function addAddressToWhitelist(address holder) external returns (bool);

    /**
     * @dev Removes `holder` address from the whitelist
     */
    function removeAddressFromWhitelist(address holder) external returns (bool);

    /**
     * @dev Accepts the future registrar role
     * NB: only the future registrar operator can call this method
     */
    function acceptRegistrarRole() external;

    /**
     * @dev Accepts the future operations role
     * NB: only the future operations operator can call this method
     */
    function acceptOperationsRole() external;

    /**
     * @dev Accepts the future technical role
     * NB: only the future technical operator can call this method
     */
    function acceptTechnicalRole() external;

    /**
     * @dev Authorizes the future new implementation contract
     * NB: only the (current) registrar operator can call this method
     */
    function authorizeImplementation(address implementation) external;
}
