// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "IERC20Operations.sol";
import "Vesting.sol";

bytes32 constant AIRDROP_ROLE_NAME = "airdrop";
bytes32 constant LOST_WALLET = keccak256("lost wallet");
bytes32 constant UNLOCK_LOCKED_TOKENS = keccak256("UNLOCK_LOCKED_TOKENS");

/**
 * @title ERC20 Utility Operations Interface
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev Interface for ERC20 utiity token operations
 * @dev Main contracts SHOULD refer to the ops contract via the this interface.
 */
interface IERC20UtilityOperations is IERC20Operations {

    /**
     * @notice Transfers tokens from the caller to a recipient and establishes
     * a vesting schedule.
     * If `transferData.toAddress` already has a locked balance, then
     * - if `transferData.amount` is greater than the airdropThreshold AND `release` is later than the current
     *      lockReleaseDate, the lockReleaseDate will be updated.
     * - if `transferData.amount` is less than the airdropThreshold OR `release` is earlier than the current
     *      lockReleaseDate, the lockReleaseDate will be left unchanged.
     * @param transferData describes the token transfer
     * @param release the new lock release date, as a Unix timestamp in seconds
     *
     * Requirements:
     * - caller MUST have the AIRDROPPER role
     * - the transaction MUST meet all requirements for a transfer
     * @dev see IERC20Operations.transfer
     */
    function airdropTimelockedTokens(
        IViciAccess ams,
        ERC20TransferData memory transferData,
        uint256 release
    ) external;

    /**
     * @notice Unlocks some or all of `account`'s locked tokens.
     * @param account the user
     * @param unlockAmount the amount to unlock
     *
     * Requirements:
     * - caller MUST be the owner or have the UNLOCK_LOCKED_TOKENS role
     * - `unlockAmount` MAY be greater than the locked balance, in which case
     *     all of the account's locked tokens are unlocked.
     */
    function unlockLockedTokens(
        IViciAccess ams,
        address operator,
        address account,
        uint256 unlockAmount
    ) external;

    /**
     * @notice Resets the lock period for a batch of addresses
     * @notice This function has no effect on accounts without a locked token balance
     * @param release the new lock release date, as a Unix timestamp in seconds
     * @param addresses the list of addresses to be reset
     *
     * Requirements:
     * - caller MUST be the owner or have the UNLOCK_LOCKED_TOKENS role
     * - `release` MAY be zero or in the past, in which case the users' entire locked balances become unlocked
     * - `addresses` MAY contain accounts without a locked balance, in which case the account is unaffected
     */
    function updateTimelocks(
        IViciAccess ams,
        address operator,
        uint256 release,
        address[] calldata addresses
    ) external;

    /**
     * @notice Returns the amount of locked tokens for `account`.
     * @param account the user address
     */
    function lockedBalanceOf(address account) external view returns (uint256);

    /**
     * @notice Returns the Unix timestamp when a user's locked tokens will be
     * released.
     * @param account the user address
     */
    function lockReleaseDate(address account) external view returns (uint256);

    /**
     * @notice Returns the difference between `account`'s total balance and its
     * locked balance.
     * @param account the user address
     */
    function unlockedBalanceOf(address account) external view returns (uint256);

    /**
     * @notice recovers tokens from lost wallets
     */
    function recoverMisplacedTokens(
        IViciAccess ams,
        address operator,
        address fromAddress,
        address toAddress
    ) external returns (uint256 amount);
}
