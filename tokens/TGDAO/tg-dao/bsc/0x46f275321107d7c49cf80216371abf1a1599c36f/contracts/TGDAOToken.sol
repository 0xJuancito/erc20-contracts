// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/ICallbackContract.sol";
import "./RecoverableFunds.sol";
import "./WithCallback.sol";
import "./interfaces/ILiquidityRestrictor.sol";
import "./interfaces/IAntisnipe.sol";


/**
 * @dev TGDAO Token
 */
contract TGDAOToken is ERC20, ERC20Burnable, RecoverableFunds, WithCallback {

    IAntisnipe public antisnipe;
    ILiquidityRestrictor public liquidityRestrictor;

    bool public antisnipeEnabled = true;
    bool public liquidityRestrictionEnabled = true;

    event AntisnipeDisabled(uint256 timestamp, address user);
    event LiquidityRestrictionDisabled(uint256 timestamp, address user);
    event AntisnipeAddressChanged(address addr);
    event LiquidityRestrictionAddressChanged(address addr);

    constructor(address[] memory initialAccounts, uint256[] memory initialBalances) payable ERC20("TGDAO", "TGDAO") {
        for (uint8 i = 0; i < initialAccounts.length; i++) {
            _mint(initialAccounts[i], initialBalances[i]);
        }
    }

    function _burn(address account, uint256 amount) internal override {
        super._burn(account, amount);
        _burnCallback(account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        super._transfer(sender, recipient, amount);
        _transferCallback(sender, recipient, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (from == address(0) || to == address(0)) return;
        if (liquidityRestrictionEnabled && address(liquidityRestrictor) != address(0)) {
            (bool allow, string memory message) = liquidityRestrictor.assureLiquidityRestrictions(from, to);
            require(allow, message);
        }
        if (antisnipeEnabled && address(antisnipe) != address(0)) {
            require(antisnipe.assureCanTransfer(msg.sender, from, to, amount));
        }
    }

    function setAntisnipeDisable() external onlyOwner {
        require(antisnipeEnabled);
        antisnipeEnabled = false;
        emit AntisnipeDisabled(block.timestamp, msg.sender);
    }

    function setLiquidityRestrictorDisable() external onlyOwner {
        require(liquidityRestrictionEnabled);
        liquidityRestrictionEnabled = false;
        emit LiquidityRestrictionDisabled(block.timestamp, msg.sender);
    }

    function setAntisnipeAddress(address addr) external onlyOwner {
        antisnipe = IAntisnipe(addr);
        emit AntisnipeAddressChanged(addr);
    }

    function setLiquidityRestrictionAddress(address addr) external onlyOwner {
        liquidityRestrictor = ILiquidityRestrictor(addr);
        emit LiquidityRestrictionAddressChanged(addr);
    }
}
