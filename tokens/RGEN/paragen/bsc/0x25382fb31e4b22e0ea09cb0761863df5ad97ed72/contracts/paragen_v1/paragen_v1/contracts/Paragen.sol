// This Contract is created for Paragen - Webiste: paragen.io

// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UsingLiquidityProtectionService.sol";

contract Paragen is
    ERC20Burnable,
    ERC20Pausable,
    ERC20Capped,
    Ownable,
    UsingLiquidityProtectionService(0x9786b0BeDC1fF41f4Dc1C471312ec1D179CBFa06)
{
    uint256 constant SUPPLY = 20e7 ether;

    constructor() ERC20("Paragen", "RGEN") ERC20Capped(SUPPLY) {
        ERC20._mint(_msgSender(), SUPPLY);
    }

    function togglePause() public onlyOwner {
        paused() ? _unpause() : _pause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
        LiquidityProtection_beforeTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        super._mint(account, amount);
    }

    function token_transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        _transfer(_from, _to, _amount); // Expose low-level token transfer function.
    }

    function token_balanceOf(address _holder)
        internal
        view
        override
        returns (uint256)
    {
        return balanceOf(_holder); // Expose balance check function.
    }

    function protectionAdminCheck() internal view override onlyOwner {} // Must revert to deny access.

    function uniswapVariety() internal pure override returns (bytes32) {
        return PANCAKESWAP; // UNISWAP / PANCAKESWAP / QUICKSWAP / SUSHISWAP / PANGOLIN / TRADERJOE.
    }

    function uniswapVersion() internal pure override returns (UniswapVersion) {
        return UniswapVersion.V2; // V2 or V3.
    }

    function uniswapFactory() internal pure override returns (address) {
        return 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73; // PancakeFactory
    }

    // All the following overrides are optional, if you want to modify default behavior.

    // How the protection gets disabled.
    function protectionChecker() internal view override returns (bool) {
        return ProtectionSwitch_timestamp(1648425599); // Switch off protection automatically on Sunday, March 27, 2022 11:59:59 PM GMT.
        // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
        //        return ProtectionSwitch_manual(); // Switch off protection by calling disableProtection(); from owner. Default.
    }

    // This token will be pooled in pair with:
    function counterToken() internal pure override returns (address) {
        return 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // BUSD
    }
}
