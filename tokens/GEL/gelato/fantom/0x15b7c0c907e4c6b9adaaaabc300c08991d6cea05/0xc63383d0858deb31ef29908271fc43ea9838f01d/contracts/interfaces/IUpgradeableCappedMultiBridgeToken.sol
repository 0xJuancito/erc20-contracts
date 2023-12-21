// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IUpgradeableCappedMultiBridgeToken {
    struct Supply {
        uint256 total;
        uint256 cap;
        uint256 epochTotal;
    }

    function updateBridgeSupplyCap(address _bridge, uint256 _cap) external;

    function updateBridgeEpochTotal(address _bridge, uint256 _total) external;

    function updateEpochLength(uint256 _epochLength) external;

    function mint(address _to, uint256 _amount) external returns (bool);

    function burn(address _from, uint256 _amount) external returns (bool);

    function supply(address _bridge) external view returns (Supply memory);

    function bridgeEpochTotalLeft(address _bridge)
        external
        view
        returns (uint256);

    function isBridge(address _bridge) external view returns (bool);

    function bridges() external view returns (address[] memory);

    function numberOfBridges() external view returns (uint256);

    function epoch() external view returns (uint256);

    function epochLength() external view returns (uint256);

    function timeUntilNextEpoch() external view returns (uint256);
}
