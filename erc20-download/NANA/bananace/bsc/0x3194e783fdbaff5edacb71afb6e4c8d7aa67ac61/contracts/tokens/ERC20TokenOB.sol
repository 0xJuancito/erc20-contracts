// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPinkAntiBot.sol";

contract ERC20TokenOB is Context, ERC20, ERC20Burnable, Ownable {
    address private immutable deployer;
    IPinkAntiBot public immutable pinkAntiBot;
    uint8 private constant DECIMALS = 18;
    bool public antiBotActive;

    constructor(string memory name_, string memory symbol_, uint initialSupply_, address antiBot_) ERC20(name_, symbol_) {
        pinkAntiBot = IPinkAntiBot(antiBot_);
        pinkAntiBot.setTokenOwner(msg.sender);
        antiBotActive = true;
        deployer = _msgSender();

        _mint(_msgSender(), (initialSupply_ * (10 ** DECIMALS)));
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    function setAntiBotState(bool antiBotActive_) public onlyOwner {
        antiBotActive = antiBotActive_;
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        if (amount > 0) {
            super._mint(account, amount);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
        if (antiBotActive) {
            pinkAntiBot.onPreTransferCheck(from, to, amount);
        }
    }
}
