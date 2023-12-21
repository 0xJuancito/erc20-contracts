//SPDX-License-Identifier:  MIT
pragma solidity ^0.8.10;

interface Errors {
    error AlreadyInitialized();
    error CallerIsNotInternalContract();
    error CallerIsNotWhitelisted();
    error InvalidWithdrawalRetention();
    error MaxGlpTvlReached();
    error CannotSettleEpochInFuture();
    error EpochAlreadySettled();
    error EpochNotSettled();
    error WithdrawalAlreadyCompleted();
    error WithdrawalWithNoShares();
    error WithdrawalSignalAlreadyDone();
    error NotRightEpoch();
    error NotEnoughStables();
    error NoEpochToSettle();
    error CannotCancelWithdrawal();
    error AddressCannotBeZeroAddress();
    error OnlyAdapter();
    error DoesntHavePermission();
}
