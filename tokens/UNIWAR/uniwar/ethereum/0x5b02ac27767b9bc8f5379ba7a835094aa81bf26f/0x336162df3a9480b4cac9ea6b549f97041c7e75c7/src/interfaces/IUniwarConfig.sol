// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IUniwarConfig {
    enum Swap { None, Buy, Sell }
    enum Forge { x, y, z }

    struct SwapLimits {
        uint16 txMax;
        uint16 walletMax;
    }

    struct SwapTaxRates {
        uint16 unibot;
        uint16 liquidity;
        uint16 treasury;
        uint16 burn;
    }

    struct ForgeWeights {
        uint8 x;
        uint8 y;
        uint8 z;
    }

    struct ForgeRates {
        uint16 x;
        uint16 y;
        uint16 z;
    }

    struct ForgeVaultLockPeriod {
        uint256 x;
        uint256 y;
        uint256 z;
    }

    function treasury() external view returns (address);
    function controller() external view returns (address);
    function lp() external view returns (address);
    function router() external view returns (address);
    function pair() external view returns (address);
    function unibot() external view returns (address);
    function uniwar() external view returns (address);
    function forge() external view returns (address);

    function phase() external view returns (uint8);
    function swapThreshold() external view returns (uint16);

    function glacialBind(address _address) external view returns (bool);
    function highElves(address _address) external view returns (bool);

    function buyLimits(uint8) external view returns (uint16, uint16);
    function sellLimits(uint8) external view returns (uint16, uint16);
    function buyTaxRates(uint8) external view returns (uint16, uint16, uint16, uint16);
    function sellTaxRates(uint8) external view returns (uint16, uint16, uint16, uint16);
    function forgeWeights(uint8) external view returns (uint8, uint8, uint8);
    function forgeStakingRates(uint8) external view returns (uint16, uint16, uint16);
    function forgeInstantWithdrawRates(uint8) external view returns (uint16, uint16, uint16);
    function forgeVaultLockPeriods(uint8) external view returns (uint256, uint256, uint256);
}
