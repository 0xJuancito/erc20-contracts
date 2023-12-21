// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.18;

/*
 * @title IBurnRedeemable Interface
 *
 * @notice This interface defines the methods related to redeemable tokens that can be burned.
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
interface IBurnRedeemable {

    /// -------------------------------------- EVENTS --------------------------------------- \\\

    /**
     * @notice Emitted when a user redeems tokens.
     * @dev This event emits the details about the redemption process.
     * @param user The address of the user who performed the redemption.
     * @param xenContract The address of the XEN contract involved in the redemption.
     * @param tokenContract The address of the token contract involved in the redemption.
     * @param xenAmount The amount of XEN redeemed by the user.
     * @param tokenAmount The amount of tokens redeemed by the user.
     */
    event Redeemed(
        address indexed user,
        address indexed xenContract,
        address indexed tokenContract,
        uint256 xenAmount,
        uint256 tokenAmount
    );

    /// --------------------------------- EXTERNAL FUNCTION --------------------------------- \\\

    /**
     * @notice Called when a token is burned by a user.
     * @dev Handles any logic related to token burning for redeemable tokens.
     * Implementations should be cautious of reentrancy attacks.
     * @param user The address of the user who burned the token.
     * @param amount The amount of the token burned.
     */
    function onTokenBurned(
        address user,
        uint256 amount
    ) external;

    /// ------------------------------------------------------------------------------------- \\\
}