// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "../lib/ERC20Blacklist.sol";
import './UsingLiquidityProtectionService.sol';

contract ZOATokenBSC is ERC20, Ownable, ERC20Pausable, ERC20Permit, ERC20Blacklist, UsingLiquidityProtectionService(0xd0B38c1018f6B15d9754ab531330c38d99d0AD47) {

    // solhint-disable-next-line func-visibility
    constructor() ERC20("ZOA", "ZOA") ERC20Permit("ZOA") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }

    function token_transfer(address _from, address _to, uint _amount) internal override {
        _transfer(_from, _to, _amount); // Expose low-level token transfer function.
    }
    function token_balanceOf(address _holder) internal view override returns(uint) {
        return balanceOf(_holder); // Expose balance check function.
    }
    function protectionAdminCheck() internal view override onlyOwner {} // Must revert to deny access.
    function uniswapVariety() internal pure override returns(bytes32) {
        return PANCAKESWAP; // UNISWAP / PANCAKESWAP / QUICKSWAP / SUSHISWAP.
    }
    function uniswapVersion() internal pure override returns(UniswapVersion) {
        return UniswapVersion.V2; // V2 or V3.
    }
    function uniswapFactory() internal pure override returns(address) {
        return 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73; // PancakeFactory
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Pausable, ERC20Blacklist)
    {
        super._beforeTokenTransfer(from, to, amount);
        LiquidityProtection_beforeTokenTransfer(from, to, amount);

    }

    // All the following overrides are optional, if you want to modify default behavior.
    // How the protection gets disabled.
    function protectionChecker() internal view override returns(bool) {
        return ProtectionSwitch_timestamp(1653868799); // Switch off protection on Sunday, May 29, 2022 11:59:59 PM GMT.
        // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
        // return ProtectionSwitch_manual(); // Switch off protection by calling disableProtection(); from owner. Default.
    }

    // This token will be pooled in pair with:
    function counterToken() internal pure override returns(address) {
        return 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // BUSD
    }
}