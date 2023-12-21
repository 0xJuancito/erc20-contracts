pragma solidity >=0.6.12;

interface IMultiAssetTreasury {
//    function addCollateralPolicy(uint256 _aid, uint256 _price_band, uint256 _missing_decimals, uint256 _init_tcr, uint256 _init_ecr) external;

    function hasPool(address _address) external view returns (bool);

    function collateralFund() external view returns (address);

    function globalCollateralBalance(uint256 _assetId) external view returns (uint256);

    function collateralValue(uint256 _assetId) external view returns (uint256);

//    function buyback(
//        uint256 _assetId,
//        uint256 _collateral_amount,
//        uint256 _min_share_amount,
//        uint256 _min_asset_out,
//        address[] calldata path
//    ) external;
//
//    function reCollateralize(uint256 _assetId, uint256 _share_amount, uint256 _min_collateral_amount, address[] calldata path) external;

    function requestTransfer(
        address token,
        address receiver,
        uint256 amount
    ) external;

    function info(uint256 _assetId)
    external
    view
    returns (
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    );
}
