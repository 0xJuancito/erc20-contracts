// SPDX-License-Identifier: MIT

pragma solidity >0.6.12;

interface ITreasury {
    function epoch() external view returns (uint);

    function startTime() external view returns (uint);

    function redeemStartTime() external view returns (uint);

    function nextEpochPoint() external view returns (uint);

    function getArbiTenPrice() external view returns (uint);

    function getArbiTenUpdatedPrice() external view returns (uint);

    function buyBonds(uint amount, uint targetPrice) external;

    function redeemBonds(uint amount, uint targetPrice) external;

    function treasuryUpdates() external;

    function _updateArbiTenPrice() external;

    function _update10SHAREPrice() external;

    function refreshCollateralRatio() external;

    function allocateSeigniorage() external;

    function hasPool(address _address) external view returns (bool);

    function info()
        external
        view
        returns (
            uint,
            uint,
            uint,
            uint,
            uint,
            uint,
            uint,
            uint
        );

    function epochInfo()
        external
        view
        returns (
            uint,
            uint,
            uint,
            uint
        );
}
