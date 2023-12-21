// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title  UUPSUpgradeableWithDelay
 * @notice extends UUPSUpgradeable to include a time delay before protocol can upgrade implementation
 */
abstract contract UUPSUpgradeableWithDelay is UUPSUpgradeable {
    uint256 public UPGRADE_DELAY;

    // implementation address => upgrade time
    mapping(address => uint256) public implementationToUpgradeTime;

    event SignalUpgrade(address, uint256);

    function __UUPSUpgradeableWithDelay_init(uint256 delay) internal onlyInitializing {
        UPGRADE_DELAY = delay;
        __UUPSUpgradeable_init();
    }

    function signalUpgrade(address _implementation) public virtual {
        _authorizeUpgradeWithDelay(_implementation);

        uint256 upgradeTime = block.timestamp + UPGRADE_DELAY;
        implementationToUpgradeTime[_implementation] = upgradeTime;

        emit SignalUpgrade(_implementation, upgradeTime);
    }

    function _authorizeUpgrade(address _implementation) internal override {
        _authorizeUpgradeWithDelay(_implementation);

        uint256 upgradeTime = implementationToUpgradeTime[_implementation];
        require(upgradeTime > 0, "NOT_SIGNALED");

        require(upgradeTime <= block.timestamp, "STILL_UNDER_DELAY");

        // Remove address from mapping such that a new signal is required
        implementationToUpgradeTime[_implementation] = 0;
    }

    function _authorizeUpgradeWithDelay(address) internal virtual;
}
