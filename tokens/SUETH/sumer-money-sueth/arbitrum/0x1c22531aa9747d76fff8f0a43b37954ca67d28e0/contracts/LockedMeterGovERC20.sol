// Copyright (c) 2018 The Meter.io developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>
pragma solidity ^0.8.0;
import "./interfaces/IMeterNative.sol";

contract LockedMeterGovERC20 {
    mapping(address => mapping(address => uint256)) allowed;
    IMeterNative _meterTracker;

    constructor() {
        _meterTracker = IMeterNative(
            0x0000000000000000004D657465724e6174697665
        );
    }

    function name() public pure returns (string memory) {
        return "StakedMeterGov";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function symbol() public pure returns (string memory) {
        return "STAKEDMTRG";
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return _meterTracker.native_mtrg_locked_get(_owner);
    }
}
