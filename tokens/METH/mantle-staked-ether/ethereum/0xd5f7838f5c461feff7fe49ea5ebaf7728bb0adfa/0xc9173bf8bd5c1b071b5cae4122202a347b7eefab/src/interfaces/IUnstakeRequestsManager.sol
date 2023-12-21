// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Staking} from "../Staking.sol";

/// @notice An unstake request is stored in the UnstakeRequestsManager and records the information required to
/// fulfill an unstake request claim.
/// @param id The unique ID of the unstake request.
/// @param requester The address of the user that requested the unstake.
/// @param mETHLocked The amount of mETH that was locked when the unstake request was created. The amount of mETH
/// will be burned once the request has been claimed.
/// @param ethRequested The amount of ETH that was requested when the unstake request was created.
/// @param cumulativeETHRequested The cumulative amount of ETH that had been requested in this request and all unstake
/// requests before this one.
/// @param blockNumber The block number at which the unstake request was created.
struct UnstakeRequest {
    uint64 blockNumber;
    address requester;
    uint128 id;
    uint128 mETHLocked;
    uint128 ethRequested;
    uint128 cumulativeETHRequested;
}

interface IUnstakeRequestsManagerWrite {
    /// @notice Creates a new unstake request and adds it to the unstake requests array.
    /// @param requester The address of the entity making the unstake request.
    /// @param mETHLocked The amount of mETH tokens currently locked in the contract.
    /// @param ethRequested The amount of ETH being requested for unstake.
    /// @return The ID of the new unstake request.
    function create(address requester, uint128 mETHLocked, uint128 ethRequested) external returns (uint256);

    /// @notice Allows the requester to claim their unstake request after it has been finalized.
    /// @param requestID The ID of the unstake request to claim.
    /// @param requester The address of the entity claiming the unstake request.
    function claim(uint256 requestID, address requester) external;

    /// @notice Cancels a batch of the latest unfinalized unstake requests.
    /// @param maxCancel The maximum number of requests to cancel.
    /// @return A boolean indicating if there are more unstake requests to cancel.
    function cancelUnfinalizedRequests(uint256 maxCancel) external returns (bool);

    /// @notice Allocate ether into the contract.
    function allocateETH() external payable;

    /// @notice Withdraws surplus ETH from the allocatedETHForClaims.
    function withdrawAllocatedETHSurplus() external;
}

interface IUnstakeRequestsManagerRead {
    /// @notice Retrieves a specific unstake request based on its ID.
    /// @param requestID The ID of the unstake request to fetch.
    /// @return The UnstakeRequest struct corresponding to the given ID.
    function requestByID(uint256 requestID) external view returns (UnstakeRequest memory);

    /// @notice Returns the status of the request whether it is finalized and how much ETH that has been filled.
    /// @param requestID The ID of the unstake request.
    /// @return bool indicating if the request is finalized, and the amount of ETH that has been filled.
    function requestInfo(uint256 requestID) external view returns (bool, uint256);

    /// @notice Calculates the amount of ether allocated in the contract exceeding the total required to pay unclaimed.
    /// @return The amount of surplus allocatedETH.
    function allocatedETHSurplus() external view returns (uint256);

    /// @notice Calculates the amount of ether that is needed to fulfill the unstake requests.
    /// @return The amount of allocatedETH deficit.
    function allocatedETHDeficit() external view returns (uint256);

    /// @notice Calculates the amount of ether that has been allocated but not yet claimed.
    /// @return The total amount of ether that is waiting to be claimed.
    function balance() external view returns (uint256);
}

interface IUnstakeRequestsManager is IUnstakeRequestsManagerRead, IUnstakeRequestsManagerWrite {}
