// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./interfaces/IVenoNft.sol";
import "./interfaces/ICroBridge.sol";
import "./interfaces/IIBCReceiver.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

/**
 * @title LiquidCroStorage
 * @dev Contains all the storage for LiquidCro. As LiquidCro is upgradable:
 *      1) do not remove or change the type for existing storage
 *      2) only add new storage variable (append at the last)
 */
contract LiquidCroStorage {
    enum UnbondingStatus {
        PENDING_BOT, // batch is waiting for bot process
        PROCESSING, // bot started processing, new unbonding request will be in next batch
        UNBONDING, // bot finished processing unbonding request for this batch
        UNBONDED // batch is unbonded, user can claim
    }

    struct UnbondRequest {
        // timestamp of when unlock request starts
        uint128 unlockStartTime;
        // timestamp of when unlock request ends
        uint128 unlockEndTime;
        // total liquidCro amount pending unlock
        uint256 liquidCroAmount;
        // liquidCro to cro rate - this can decrease in the event of slashing, require divide by 1e18
        uint256 liquidCro2CroExchangeRate;
        // unbond request batch
        uint256 batchNo;
    }

    uint8 public constant EXCHANGE_RATE_DECIMAL = 8;
    // exchange rate = totalSupply() / totalPooledCro which could be 1.01
    // multiply by 1e8 to get up to 8 decimals precision
    uint256 public constant EXCHANGE_RATE_PRECISION = 10**EXCHANGE_RATE_DECIMAL;

    /// @dev includes action such as accrueReward, bridge, pause
    bytes32 public constant ROLE_BOT = keccak256("ROLE_BOT");

    /// @dev include action involving user's fund (eg. slashing)
    bytes32 public constant ROLE_SLASHER = keccak256("ROLE_SLASHER");

    IVenoNft public venoNft;

    ICroBridge public croBridge;

    IIBCReceiver public ibcReceiver;

    // Batch no for new unbonding request, batch no will increase when current batch is processing
    uint256 public currentUnbondingBatchNo;

    // Unbonding Batch no => unbonding status
    mapping(uint256 => UnbondingStatus) public batch2UnbondingStatus;

    // tokenId to withdrawal request
    mapping(uint256 => UnbondRequest) public token2UnbondRequest;

    // list of unclaimed unbond requests
    EnumerableSetUpgradeable.UintSet internal unbondRequests;

    // Crypto.org txn hash ==> reward accrued
    mapping(string => uint256) public txnHash2AccrueRewardAmount;

    // validator address => time => amount
    mapping(string => mapping(uint256 => uint256)) public validator2Time2AmountSlashed;

    address public treasury;

    // Unbonding fee - 100 = 0.1%, 200 = 0.2%
    uint256 public unbondingFee;

    // Unbonding time by the bot, eg. 4 days 15 mins at the worst case
    // 1. 4 days from max 7 unbonding per validator
    // 2. 15 mins from bot processing (gather unbonding request or ibc back to cronos)
    uint256 public unbondingProcessingTime;

    // Unbonding duration - eg. 28 days
    uint256 public unbondingDuration;

    // 1000 = 1% for unbonding fee, thus 100_000 represent 100%
    uint256 public constant UNBONDING_FEE_DENOMINATOR = 100_000;

    // The total amount of CRO with the protocol
    uint256 public totalPooledCro;

    // Last time where bot unbond from delegator
    uint256 public lastUnbondTime;

    // Total amount of CRO pending to be bridged and delegated
    uint256 public totalCroToBridge;

    // Bridge destination on Crypto.org chain
    string public bridgeDestination;
}
