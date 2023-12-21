// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/**
 * @dev Flow limiter by quota.
 *      There are user quotas and also a global quota.
 *      The user quota regenerates per second, and so does the global quota.
 *      The flow limiter will revert if EITHER user or global quota is exceeded.
 *
 */
/* solhint-disable not-rely-on-time */
abstract contract FlowLimiter is Context, AccessControlEnumerable {
    // ENUMS

    enum FlowDirection {
        IN,
        OUT
    }

    // VARS

    // max global quota per direction
    uint256 public globalQuota;
    // max quota (per user, per direction)
    uint256 public userQuota;
    // amount of quota unlocked per second on global limit
    uint256 public globalQuotaRegenRate;
    // amount of quota unlocked per second per user
    uint256 public userQuotaRegenRate;
    // mapping (transfer direction -> global quota info)
    mapping(FlowDirection => QuotaInfo) public globalQuotaMap;
    // mapping (user -> transfer direction -> user quota info)
    mapping(address => mapping(FlowDirection => QuotaInfo)) public userQuotaMap;

    // STRUCTS

    // Quota consumption info
    struct QuotaInfo {
        // timestamp of last quota
        uint256 lastUpdated;
        // amount of quota used
        uint256 quotaUsed;
    }

    // EVENTS

    event SetGlobalQuota(address indexed caller, uint256 indexed oldQuota, uint256 indexed newQuota);
    event SetUserQuota(address indexed caller, uint256 indexed oldQuota, uint256 indexed newQuota);
    event SetGlobalQuotaRegenRate(address indexed caller, uint256 indexed oldRate, uint256 indexed newRate);
    event SetUserQuotaRegenRate(address indexed caller, uint256 indexed oldRate, uint256 indexed newRate);

    // CONFIG PARAMS

    // sets global quota (per direction)
    function setGlobalQuota(uint256 _globalQuota) public {
        // must be admin
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");
        // emit
        emit SetGlobalQuota(_msgSender(), globalQuota, _globalQuota);
        // set
        globalQuota = _globalQuota;
    }

    // sets user quota (quota per user, per direction)
    function setUserQuota(uint256 _userQuota) public {
        // must be admin
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");
        // emit
        emit SetUserQuota(_msgSender(), userQuota, _userQuota);
        // set
        userQuota = _userQuota;
    }

    // sets quota regeneration rate (global, per second)
    function setGlobalQuotaRegenRate(uint256 _globalQuotaRegenRate) public {
        // must be admin
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");
        // emit
        emit SetGlobalQuotaRegenRate(_msgSender(), globalQuotaRegenRate, _globalQuotaRegenRate);
        // set
        globalQuotaRegenRate = _globalQuotaRegenRate;
    }

    // sets regeneration rate (per user, per second)
    function setUserQuotaRegenRate(uint256 _userQuotaRegenRate) public {
        // must be admin
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");
        // emit
        emit SetUserQuotaRegenRate(_msgSender(), userQuotaRegenRate, _userQuotaRegenRate);
        // set
        userQuotaRegenRate = _userQuotaRegenRate;
    }

    // QUOTA FUNCTIONS

    // gets the quota for a particular user
    function userQuotaForToken(address user, FlowDirection direction) public view returns (uint256 quota) {
        QuotaInfo memory quotaInfo = userQuotaMap[user][direction];
        return quotaInfo.quotaUsed;
    }

    // sets the quota for a particular user
    function consumeQuotaOfUser(
        address user,
        FlowDirection direction,
        uint256 amount
    ) internal {
        // get current global quota info
        QuotaInfo storage globalQuotaInfo = globalQuotaMap[direction];
        // get current user quota info
        QuotaInfo storage userQuotaInfo = userQuotaMap[user][direction];

        // calculate amount of quota unlocked
        uint256 globalUnlocked = globalQuotaRegenRate * (block.timestamp - globalQuotaInfo.lastUpdated); // global
        uint256 userUnlocked = userQuotaRegenRate * (block.timestamp - userQuotaInfo.lastUpdated); // user
        // calculate new amount of quota used
        uint256 newGlobalUsage = (globalQuotaInfo.quotaUsed + amount > globalUnlocked)
            ? globalQuotaInfo.quotaUsed + amount - globalUnlocked
            : 0;
        uint256 newUserUsage = (userQuotaInfo.quotaUsed + amount > userUnlocked)
            ? userQuotaInfo.quotaUsed + amount - userUnlocked
            : 0;

        // ensure usage does not exceed limit
        require(newGlobalUsage <= globalQuota, "Usage exceeds global quota");
        require(newUserUsage <= userQuota, "Usage exceeds user quota");

        // update global quota info
        globalQuotaInfo.quotaUsed = newGlobalUsage;
        globalQuotaInfo.lastUpdated = block.timestamp;
        // update user quota info
        userQuotaInfo.quotaUsed = newUserUsage;
        userQuotaInfo.lastUpdated = block.timestamp;
    }
}
