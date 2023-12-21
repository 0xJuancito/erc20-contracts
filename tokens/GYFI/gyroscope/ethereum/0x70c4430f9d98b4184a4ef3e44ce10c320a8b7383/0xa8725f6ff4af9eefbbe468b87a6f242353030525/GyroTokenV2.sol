// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "GyroToken.sol";

contract GyroTokenV2 is GyroToken {
    bool internal _inflationReinitialized;

    function reinitializeLatestInflation() external {
        require(!_inflationReinitialized, "already reinitialized");
        latestInflationTimestamp = uint64(block.timestamp) + INITIAL_INFLATION_DELAY;
        _inflationReinitialized = true;
    }
}
