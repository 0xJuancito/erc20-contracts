// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title  PoolTogether V5 Claimable Interface
 * @author G9 Software Inc.
 * @notice Provides a concise and consistent interface for Claimer contracts to interact with Vaults
 * in PoolTogether V5.
 */
interface IClaimable {
  /**
   * @notice Emitted when a new claimer has been set
   * @dev This event MUST be emitted when a new claimer has been set.
   * @param claimer Address of the new claimer
   */
  event ClaimerSet(address indexed claimer);

  /**
   * @notice Claim a prize for a winner
   * @param _winner The winner of the prize
   * @param _tier The prize tier
   * @param _prizeIndex The prize index
   * @param _fee The fee to charge, in prize tokens
   * @param _feeRecipient The recipient of the fee
   * @return The total prize token amount claimed (zero if already claimed)
   */
  function claimPrize(
    address _winner,
    uint8 _tier,
    uint32 _prizeIndex,
    uint96 _fee,
    address _feeRecipient
  ) external returns (uint256);

  /**
   * @notice Gets the current address that can call `claimPrize`.
   * @return The claimer address
   */
  function claimer() external returns (address);
}
