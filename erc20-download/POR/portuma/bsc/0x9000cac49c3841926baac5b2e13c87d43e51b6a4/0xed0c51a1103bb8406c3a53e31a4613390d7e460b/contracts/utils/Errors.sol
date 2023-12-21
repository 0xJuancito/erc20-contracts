// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// Insufficient balance for transfer. Needed `required` but only
/// `available` available.
/// @param available balance available.
/// @param required requested amount to transfer.
error InsufficientBalance(uint256 available, uint256 required);

/// Maximum allowed transaction amount should not be more than the defined limit
/// @param limit defined limit
/// @param sent requested amount
error MaxTransactionAmountExeeds(uint256 limit, uint256 sent);

/// Requested address is already excluded from Reward(RFI)
/// @param account requested address
error AccountAlreadyExcludedFromReward(address account);

/// Requested address is already included in Reward(RFI)
/// @param account requested address
error AccountAlreadyIncludedInReward(address account);

/// Requested address is already excluded from paying fees
/// @param account requested address
error AccountAlreadyExcludedFromFee(address account);

/// Requested address is already included in paying fees
/// @param account requested address
error AccountAlreadyIncludedInFee(address account);

/// Requested address can not be Zero address
/// @param account requested address
error AddressIsZero(address account);

/// Requested amount can not be zero
error AmountIsZero();

/// Requested address is already in the market makers list
/// @param pair requested address
/// @param value requested value
error MarketMakerAlreadySet(address pair, bool value);

/// Requested pair address is already set
/// @param pair requested address
error PairAlreadySet(address pair);

/// Requested trading status value is already set
/// @param value requested value
error TradingStatusAlreadySet(bool value);

/// Requested status value is already set in Blaclist for this account
/// @param account requested address
/// @param value requested value
error BlaclistStatusAlreadySet(address account, bool value);

/// Requested amount exceeds the total reflection amount
/// @param amount requested amount
error AmountExceedsTotalReflection(uint256 amount);

/// Requested amount exceeds the total supply amount
/// @param amount requedted amount
error AmountExceedsTotalSupply(uint256 amount);

/// Requested addresses can not be Zero address
/// @param sender requested sender address
/// @param recipient requested recipient address
error SenderOrRecipientAddressIsZero(address sender, address recipient);

/// Requested addresses in the blacklist
/// @param sender requested sender address
/// @param recipient requested recipient address
error SenderOrRecipientBlacklisted(address sender, address recipient);

/// Trading status is currently not activated
error TradingNotStarted();

/// Requested contract tokens can not be transferred out
error CannotTransferContractTokens();

/// Requested amount exceeds the total balance of rrequested account
error AmountExceedsAccountBalance();

/// Reentrancy check on swapping
error noReentrancyOnSwap();

/// Giving list exceeds the max length
/// @param maxLength Allowed max length
error MaxLengthExeeds(uint256 maxLength);

/// giving data lengths are not equal
/// @param aLength A side length
/// @param bLength B side length
error MismatchLength(uint256 aLength, uint256 bLength);