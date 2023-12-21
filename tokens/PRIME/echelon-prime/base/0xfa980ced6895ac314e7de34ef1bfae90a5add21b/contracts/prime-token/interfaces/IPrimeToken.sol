// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPrimeToken {
    /**
     * @dev Emitted when the new forwarder is set
     * @param forwarder The address of the new forwarder
     */
    event TrustedForwarderSet(address forwarder);

    /**
     * @dev Fired when a new gateway (i.e. echelon handler contract) is registered
     * @param contractAddress - The address of the newly registered invokeEchelon handler contract
     * @param nativeTokenDestinationAddress - The address to which MATIC or whatever native token was collected
     * @param primeDestinationAddress - The address to which PRIME was collected
     */
    event EchelonGatewayRegistered(
        address indexed contractAddress,
        address indexed nativeTokenDestinationAddress,
        address indexed primeDestinationAddress
    );

    /**
     * @dev Fired when the handler is invoked
     * @param from - The address of the invoker
     * @param ethDestination - The address to which ETH or whatever native token was collected
     * @param primeDestination - The address to which PRIME was collected
     * @param id - The arbitrary identifier used for tracking
     * @param ethValue - The amount of ETH or whatever native token that was sent
     * @param primeValue - The amount of PRIME that was sent
     * @param data - Additional data that was sent
     */
    event EchelonInvoked(
        address indexed from,
        address indexed ethDestination,
        address indexed primeDestination,
        uint256 id,
        uint256 ethValue,
        uint256 primeValue,
        bytes data
    );
}
