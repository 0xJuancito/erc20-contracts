// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

struct Snapshots {
    uint256[] ids;
    uint256[] values;
}

contract SnapshotStorage {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    mapping(address => Snapshots) private _accountBalanceSnapshots;
    Snapshots private _totalSupplySnapshots;
    CountersUpgradeable.Counter private _currentSnapshotId;
    uint256[46] private __gap;
}