// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

interface ITimeLocked {
    event LockerAdded(address);
    event LockerRemoved(address);

    function addLocker(address locker) external;

    function removeLocker(address locker) external;

    function setLockEnd(uint256 lockEnd) external;

    function lockAmount(address account, uint256 amount) external;

    function lockEnd() external view returns (uint256);

    function unlockedBalance(address account) external view returns (uint256);

    function isLocker(address account) external view returns (bool);

    function isLockPeriodActive() external view returns (bool);
}
