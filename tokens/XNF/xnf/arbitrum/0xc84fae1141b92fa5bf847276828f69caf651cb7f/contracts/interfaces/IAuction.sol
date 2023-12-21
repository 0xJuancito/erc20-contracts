// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.18;

/*
 * @title IAuction Interface
 *
 * @notice This interface defines the essential functions for an auction contract,
 * facilitating token burning, reward distribution, and cycle management. It provides
 * a standardized way to interact with different auction implementations.
 *
 * Co-Founders:
 * - Simran Dhillon: simran@xenify.io
 * - Hardev Dhillon: hardev@xenify.io
 * - Dayana Plaz: dayana@xenify.io
 *
 * Official Links:
 * - Twitter: https://twitter.com/xenify_io
 * - Telegram: https://t.me/xenify_io
 * - Website: https://xenify.io
 *
 * Disclaimer:
 * This contract aligns with the principles of the Fair Crypto Foundation, promoting self-custody, transparency, consensus-based
 * trust, and permissionless value exchange. There are no administrative access keys, underscoring our commitment to decentralization.
 * Engaging with this contract involves technical and legal risks. Users must conduct their own due diligence and ensure compliance
 * with local laws and regulations. The software is provided "AS-IS," without warranties, and the co-founders and developers disclaim
 * all liability for any vulnerabilities, exploits, errors, or breaches that may occur. By using this contract, users accept all associated
 * risks and this disclaimer. The co-founders, developers, or related parties will not bear liability for any consequences of non-compliance.
 *
 * Redistribution and Use:
 * Redistribution, modification, or repurposing of this contract, in whole or in part, is strictly prohibited without express written
 * approval from all co-founders. Approval requests must be sent to the official email addresses of the co-founders, ensuring responses
 * are received directly from these addresses. Proposals for redistribution, modification, or repurposing must include a detailed explanation
 * of the intended changes or uses and the reasons behind them. The co-founders reserve the right to request additional information or
 * clarification as necessary. Approval is at the sole discretion of the co-founders and may be subject to conditions to uphold the
 * project’s integrity and the values of the Fair Crypto Foundation. Failure to obtain express written approval prior to any redistribution,
 * modification, or repurposing will result in a breach of these terms and immediate legal action.
 *
 * Copyright and License:
 * Copyright © 2023 Xenify (Simran Dhillon, Hardev Dhillon, Dayana Plaz). All rights reserved.
 * This software is provided 'as is' and may be used by the recipient. No permission is granted for redistribution,
 * modification, or repurposing of this contract. Any use beyond the scope defined herein may be subject to legal action.
 */
interface IAuction {

    /// --------------------------------- EXTERNAL FUNCTIONS -------------------------------- \\\

    /**
     * @notice Enables users to recycle their native rewards and claim other rewards.
     */
    function recycle() external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to claim all their pending rewards.
     */
    function claimAll() external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to claim their pending XNF rewards.
     */
    function claimXNF() external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to claim XNF rewards and locks them in the veXNF contract for a year.
     */
    function claimVeXNF() external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to claim their native rewards.
     */
    function claimNative() external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Updates the statistics related to the provided user address.
     */
    function updateStats(address) external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to recycle native rewards and claim all other rewards.
     */
    function claimAllAndRecycle() external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Claims all pending rewards for a specific user.
     * @dev This function aggregates all rewards and claims them in a single transaction.
     * It should be invoked by the veXNF contract before any burn action.
     */
    function claimAllForUser(address) external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Claims the accumulated veXNF rewards for a specific user.
     * @dev This function mints and transfers the veXNF tokens to the user.
     * It should be invoked by the veXNF contract.
     */
    function claimVeXNFForUser(address) external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns specified batches of vXEN or YSL tokens to earn rewards.
     */
    function burn(bool, uint256) external payable;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the current cycle number of the auction.
     * @dev A cycle represents a specific duration or round in the auction process.
     * @return The current cycle number.
     */
    function currentCycle() external returns (uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Updates and retrieves the current cycle number of the auction.
     * @dev A cycle represents a specific duration or round in the auction process.
     * @return The current cycle number.
     */
    function calculateCycle() external returns (uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the number of the last active cycle.
     * @dev Useful for determining the most recent cycle with recorded activity.
     * @return The number of the last active cycle.
     */
    function lastActiveCycle() external returns (uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Registers the caller as a burner by paying in native tokens.
     */
    function participateWithNative(uint256) external payable;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the current cycle number based on the time elapsed since the contract's initialization.
     * @return The current cycle number.
     */
    function getCurrentCycle() external view returns (uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Calculates the pending native token rewards for a user based on their NFT ownership and recycling activities.
     * @return The amount of pending native token rewards.
     */
    function pendingNative(address) external view returns (uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Determines the burn and native fee for a given number of batches, adjusting for the time within the current cycle.
     * @return The calculated burn and native fee.
     */
    function coefficientWrapper(uint256) external view returns (uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Calculates the reward amount for a given cycle, adjusting for halving events.
     * @return The calculated reward amount.
     */
    function calculateRewardPerCycle(uint256) external view returns (uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Calculates the pending native token rewards for a user for the current cycle based on their NFT ownership and recycling activities.
     * @return The amount of pending native token rewards.
     */
    function pendingNativeForCurrentCycle(address) external view returns (uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Computes the pending XNF rewards for a user across various activities.
     * @return pendingXNFRewards An array containing the pending XNF rewards amounts for different activities.
     */
    function pendingXNF(address _user) external view returns (uint256, uint256, uint256);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Registers the caller as a swap user and earns rewards.
     */
    function registerSwapUser(bytes calldata, address, uint256, address) external payable;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Computes the pending XNF rewards for a user for the current cycle across various activities.
     * @return pendingXNFRewards An array containing the pending XNF rewards amounts for different activities.
     */
    function pendingXNFForCurrentCycle(address _user) external view returns (uint256, uint256, uint256);

    /// ------------------------------------------------------------------------------------- \\\
}