// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './UsingLiquidityProtectionService.sol';
import "./ERC20Blacklist.sol";
import "./PLPS_constants.sol";

contract ERC20BlacklistWithProtection is
    UsingLiquidityProtectionService(_liquidityProtectionServiceAddress),
    ERC20Blacklist
{
    constructor(string memory name, string memory symbol, uint256 cap) ERC20Blacklist(name, symbol, cap) {}

    function token_transfer(address _from, address _to, uint _amount) internal override {
        _transfer(_from, _to, _amount);
    }

    function token_balanceOf(address _holder) internal view override returns (uint) {
        return balanceOf(_holder);
    }

    function protectionAdminCheck() internal view override onlyRole(DEFAULT_ADMIN_ROLE) {} // Must revert to deny access.
    function uniswapVariety() internal pure override returns (bytes32) {
        return PANCAKESWAP_V3;
    }

    function uniswapVersion() internal pure override returns (UniswapVersion) {
        return UniswapVersion.V3;
    }
    // For PancakeV3 factory is the PoolDeployer address.
    function uniswapFactory() internal pure override returns (address) {
        return _uniswapFactoryAddress;
    }

    function _beforeTokenTransfer(address _from, address _to, uint _amount) internal override {
        super._beforeTokenTransfer(_from, _to, _amount);
        LiquidityProtection_beforeTokenTransfer(_from, _to, _amount);
    }

    // All the following overrides are optional, if you want to modify default behavior.

    // How the protection gets disabled.
    function protectionChecker() internal view override returns (bool) {
        return ProtectionSwitch_timestamp(1686873599); // Switch off protection on Thursday, June 15, 2023 11:59:59 PM GMT.
        // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
        // return ProtectionSwitch_manual(); // Switch off protection by calling disableProtection(); from owner. Default.
    }

    // How the extra protection (sandwich trap) gets disabled.
    function protectionCheckerExtra() internal view override returns (bool) {
        // return ProtectionSwitch_timestamp(1650644191); // Switch off protection on Friday, April 22, 2022 4:16:31 PM.
        // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
        return ProtectionSwitch_manual_extra();  // Switch off protection by calling disableProtectionExtra(); from owner. Default.
    }

    // This token will be pooled in pair with:
    function counterToken() internal pure override returns (address) {
        // USDT
         return _counterUsdtTokenAddress;
    }

    // This token will be pooled with fees:
    function uniswapV3Fee() internal pure override returns (UniswapV3Fees) {
        return UniswapV3Fees._025;
    }
}