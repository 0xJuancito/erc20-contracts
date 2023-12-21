// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface IPriceFeed {

    // --- Events ---
    event LastGoodPriceUpdated(address _collateral, uint _lastGoodPrice);
   
    // --- Function ---
    function fetchPrice(address _collateral) external returns (uint);
}
