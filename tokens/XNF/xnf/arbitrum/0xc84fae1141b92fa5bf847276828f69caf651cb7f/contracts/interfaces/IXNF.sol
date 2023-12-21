// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.18;

import {ILayerZeroReceiver} from "@layerzerolabs/lz-evm-sdk-v1-0.7/contracts/interfaces/ILayerZeroReceiver.sol";
import {IWormholeReceiver} from "./IWormholeReceiver.sol";

/*
 * @title XNF interface
 *
 * @notice This is an interface outlining functiosn for XNF token with enhanced features such as token locking and specialized minting
 * and burning mechanisms. It's primarily used within a broader protocol to reward users who burn YSL or vXEN.
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
interface IXNF
{
    /// -------------------------------------- ERRORS --------------------------------------- \\\

    /**
     * @notice This error is thrown when minting XNF to zero address.
     */
    error ZeroAddress();

    /**
     * @notice This error is thrown when trying to claim airdroped XNF before 2 hours passed.
     */
    error TooEarlyToClaim();

    /**
     * @notice Error thrown when minting would exceed the maximum allowed supply.
     */
    error ExceedsMaxSupply();

    /**
     * @notice This error is thrown when an invalid claim proof is provided.
     */
    error InvalidClaimProof();

    /**
     * @notice Error thrown when a function is called by an account other than the Auction contract.
     */
    error OnlyAuctionAllowed();

    /**
     * @notice This error is thrown when user tries to purchase XNF from protocol owned liquidity.
     */
    error CantPurchaseFromPOL();

    /**
     * @notice This error is thrown when user tries to sell XNF directly.
     */
    error CanSellOnlyViaRecycle();

    /**
     * @notice Error thrown when the calling contract does not support the required interface.
     */
    error UnsupportedInterface();

    /**
     * @notice This error is thrown when an airdrop has already been claimed.
     */
    error AirdropAlreadyClaimed();

    /**
     * @notice Error thrown when a user tries to transfer more unlocked tokens than they have.
     */
    error InsufficientUnlockedTokens();

    /**
     * @notice Error thrown when the contract is already initialised.
     */
    error ContractInitialised(address auction);

    /// ------------------------------------- STRUCTURES ------------------------------------ \\\

    /**
     * @notice Represents token lock details for a user.
     * @param amount Total tokens locked.
     * @param timestamp When the tokens were locked.
     * @param dailyUnlockAmount Tokens unlocked daily.
     * @param usedAmount Tokens transferred from the locked amount.
     */
    struct Lock {
        uint256 amount;
        uint256 timestamp;
        uint128 dailyUnlockAmount;
        uint128 usedAmount;
    }

    /// -------------------------------------- EVENTS --------------------------------------- \\\

    /**
     * @notice Emitted when a user successfully claims their airdrop.
     * @param user Address of the user claiming the airdrop.
     * @param amount Amount of Airdrop claimed.
     */
    event Airdropped(
        address indexed user,
        uint256 amount
    );

    /// --------------------------------- EXTERNAL FUNCTIONS -------------------------------- \\\

    /**
     * @notice Allows users to claim their airdropped tokens using a Merkle proof.
     * @dev Verifies the Merkle proof against the stored Merkle root and mints the claimed amount to the user.
     * @param proof Array of bytes32 values representing the Merkle proof.
     * @param account Address of the user claiming the airdrop.
     * @param amount Amount of tokens being claimed.
     */
    function claim(
        bytes32[] calldata proof,
        address account,
        uint256 amount
    ) external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Mints XNF tokens to a specified account.
     * @dev Only the Auction contract can mint tokens, and the total supply cap is checked before minting.
     * @param account Address receiving the minted tokens.
     * @param amount Number of tokens to mint.
     */
    function mint(
        address account,
        uint256 amount
    ) external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Sets the liquidity pool (LP) address.
     * @dev Only the Auction contract is allowed to call this function.
     * @param _lp The address of the liquidity pool to be set.
     */
    function setLPAddress(address _lp) external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns a specified amount of tokens from a user's account.
     * @dev The calling contract must support the IBurnRedeemable interface.
     * @param user Address from which tokens will be burned.
     * @param amount Number of tokens to burn.
     */
    function burn(
        address user,
        uint256 amount
    ) external;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Determines the number of days since a user's tokens were locked.
     * @dev If the elapsed days exceed the lock period, it returns the lock period.
     * @param _user Address of the user to check.
     * @return passedDays Number of days since the user's tokens were locked, capped at the lock period.
     */
    function daysPassed(address _user) external view returns (uint256 passedDays);

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Computes the amount of unlocked tokens for a user based on the elapsed time since locking.
     * @dev If the user's tokens have been locked for the full lock period, all tokens are considered unlocked.
     * @param _user Address of the user to check.
     * @return unlockedTokens Number of tokens that are currently unlocked for the user.
     */
    function getUnlockedTokensAmount(address _user) external view returns (uint256 unlockedTokens);

    /// ------------------------------------------------------------------------------------- \\\
}