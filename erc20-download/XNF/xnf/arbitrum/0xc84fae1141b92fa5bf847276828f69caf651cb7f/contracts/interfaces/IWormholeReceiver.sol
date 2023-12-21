// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.18;

/*
 * @title IWormholeReceiver Interface
 *
 * @notice Interface for a contract which can receive Wormhole messages.
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
interface IWormholeReceiver {

    /// --------------------------------- EXTERNAL FUNCTION --------------------------------- \\\

    /**
     * @notice Called by the WormholeRelayer contract to deliver a Wormhole message to this contract.
     *
     * @dev This function should be implemented to include access controls to ensure that only
     *      the Wormhole Relayer contract can invoke it.
     *
     *      Implementations should:
     *      - Maintain a mapping of received `deliveryHash`s to prevent duplicate message delivery.
     *      - Verify the authenticity of `sourceChain` and `sourceAddress` to prevent unauthorized or malicious calls.
     *
     * @param payload The arbitrary data included in the message by the sender.
     * @param additionalVaas Additional VAAs that were requested to be included in this delivery.
     *                       Guaranteed to be in the same order as specified by the sender.
     * @param sourceAddress The Wormhole-formatted address of the message sender on the originating chain.
     * @param sourceChain The Wormhole Chain ID of the originating blockchain.
     * @param deliveryHash The VAA hash of the deliveryVAA, used to prevent duplicate delivery.
     *
     * Warning: The provided VAAs are NOT verified by the Wormhole core contract prior to this call.
     *          Always invoke `parseAndVerify()` on the Wormhole core contract to validate the VAAs before trusting them.
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalVaas,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable;

    /// ------------------------------------------------------------------------------------- \\\
}