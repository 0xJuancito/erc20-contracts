// Be name Khoda
// Bime Abolfazl

// SPDX-License-Identifier: GPL-2.0-or-later

interface IDEIStablecoin {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function global_collateral_ratio() external view returns (uint256);
    function dei_pools(address _address) external view returns (bool);
    function dei_pools_array() external view returns (address[] memory);
    function verify_price(bytes32 sighash, bytes[] calldata sigs) external view returns (bool);
    function dei_info(uint256[] memory collat_usd_price) external view returns (uint256, uint256, uint256);
    function getChainID() external view returns (uint256);
    function globalCollateralValue(uint256[] memory collat_usd_price) external view returns (uint256);
    function refreshCollateralRatio(uint deus_price, uint dei_price, uint256 expire_block, bytes[] calldata sigs) external;
    function useGrowthRatio(bool _use_growth_ratio) external;
    function setGrowthRatioBands(uint256 _GR_top_band, uint256 _GR_bottom_band) external;
    function setPriceBands(uint256 _top_band, uint256 _bottom_band) external;
    function activateDIP(bool _activate) external;
    function pool_burn_from(address b_address, uint256 b_amount) external;
    function pool_mint(address m_address, uint256 m_amount) external;
    function addPool(address pool_address) external;
    function removePool(address pool_address) external;
    function setNameAndSymbol(string memory _name, string memory _symbol) external;
    function setOracle(address _oracle) external;
    function setDEIStep(uint256 _new_step) external;
    function setReserveTracker(address _reserve_tracker_address) external;
    function setRefreshCooldown(uint256 _new_cooldown) external;
    function setDEUSAddress(address _deus_address) external;
    function toggleCollateralRatio() external;
}

//Dar panah khoda