// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface EchelonGateways {
    // Invoked by the Prime Token contract to handle arbitrary functionalities by the given gateway
    function handleInvokeEchelon(
        address from,
        address ethDestination,
        address primeDestination,
        uint256 id,
        uint256 ethValue,
        uint256 primeValue,
        bytes calldata data
    ) external payable;
}
