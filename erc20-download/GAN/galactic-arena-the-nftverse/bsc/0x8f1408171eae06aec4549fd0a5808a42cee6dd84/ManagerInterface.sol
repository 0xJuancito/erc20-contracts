// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0 <0.9.0;

interface ManagerInterface {
    
    function isOperator(address _address) external view returns (bool);

    function isNftVisit(address _address) external view returns (bool);
    
    function markets(address _address) external view returns (bool);

    function farmOwners(address _address) external view returns (bool);

    function timesBattle(uint256 level) external view returns (uint256);

    function timeLimitBattle() external view returns (uint256);

    function generation() external view returns (uint256);

    function xBattle() external view returns (uint256);

    function priceEgg() external view returns (uint256);

    function divPercent() external view returns (uint256);

    function feeChangeTribe() external view returns (uint256);

    function feeMarketRate() external view returns (uint256);

    function loseRate() external view returns (uint256);

    function feeEvolve() external view returns (uint256);

    function feeAddress() external view returns (address);
    
    function getSeedForRandom() external view returns (uint256);

    function updateSeedForRandom() external;
    
    function commissionRateEgg() external view returns(uint256);
    
    function commissionRateMarket() external view returns(uint256);

    function nftStakingAmount() external view returns(uint256);
    
    function minBalanceToPvP() external view returns(uint256);
}