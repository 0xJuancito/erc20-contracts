// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import './UsingLiquidityProtectionService.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract BLPToken is ERC20, Ownable, UsingLiquidityProtectionService {
    function token_transfer(address _from, address _to, uint _amount) internal override {
        _transfer(_from, _to, _amount); // Expose low-level token transfer function.
    }
    function token_balanceOf(address _holder) internal view override returns(uint) {
        return balanceOf(_holder); // Expose balance check function.
    }
    function protectionAdminCheck() internal view override onlyOwner {} // Must revert to deny access.
    function liquidityProtectionService() internal pure override returns(address) {
        return 0xaa4a99eE0B9e1D4F0028e120a54020b391954346;
    }
    function uniswapVariety() internal pure override returns(bytes32) {
        return PANCAKESWAP;
    }
    function uniswapVersion() internal pure override returns(UniswapVersion) {
        return UniswapVersion.V2; // V2 or V3.
    }
    function uniswapFactory() internal pure override returns(address) {
        return 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73; // Replace with the correct address.
    }
    function _beforeTokenTransfer(address _from, address _to, uint _amount) internal override {
        super._beforeTokenTransfer(_from, _to, _amount);
        LiquidityProtection_beforeTokenTransfer(_from, _to, _amount);
    }
    // All the following overrides are optional, if you want to modify default behavior.

    // How the protection gets disabled.
    function protectionChecker() internal view override returns(bool) {
         return ProtectionSwitch_timestamp(1624147199); // Switch off protection on Saturday, June 19, 2021 11:59:59 PM GTM.
        // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
//        return ProtectionSwitch_manual(); // Switch off protection by calling disableProtection(); from owner. Default.
    }

    // This token will be pooled in pair with:
    function counterToken() internal pure override returns(address) {
        return 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WETH
    }


    constructor() public ERC20('Bull Perks', 'BLP') {
        _mint(owner(), 300000000 * 1e18);
    }
}
