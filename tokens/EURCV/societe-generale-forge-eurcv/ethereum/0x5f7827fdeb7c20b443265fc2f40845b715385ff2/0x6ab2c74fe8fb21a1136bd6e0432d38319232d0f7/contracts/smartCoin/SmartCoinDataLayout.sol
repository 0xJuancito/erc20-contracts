// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.17;

/**
 * @dev This contract contains the storage part of the SmartCoin contract.
 * It includes a __gap field that enables adding new fields without messing up the layout
 * and keeping compatibility accross UUPS updates (see field description for details)
 */
abstract contract SmartCoinDataLayout {
    /**
     * @dev The different status a transfer request can have
     * Transfer requests are initially in the `Created` state
     * If validated by the registrar operator they move to the `Validated` state, which is a final state
     * If rejected by the registrar operator  they move to the `Rejected` state, which is a final state
     *
     */
    enum TransferStatus {
        Undefined,
        Created,
        Validated,
        Rejected
    }
    /**
     * @dev The details of a transfer request
     */
    struct TransferRequest {
        /**
         * @dev The source address of the transfer
         */
        address from;
        /**
         * @dev The destination address of the transfer
         */
        address to;
        /**
         * @dev The number of tokens to transfer
         */
        uint256 value;
        /**
         * @dev The status of the transfer request
         */
        TransferStatus status;
    }

    /**
     * @dev Structure containing all ongoing transfer requests
     * Requests are indexed by the hash of their content
     */
    mapping(bytes32 => TransferRequest) internal _transfers;
    uint256 internal _requestCounter;

    /**
     * @dev Structure containing all amounts currently engaged(i.e. "locked") in transfer requests
     */
    mapping(address => uint256) internal _engagedAmount; // _engagedAmount amount in transfer

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
