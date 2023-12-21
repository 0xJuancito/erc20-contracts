// contracts/IUX
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IAntisnipe {
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external;
}

contract IUX is ERC20, ERC20Burnable, Pausable, Ownable {
    IAntisnipe public antisnipe = IAntisnipe(address(0));
    bool public antisnipeDisable;    

    constructor(uint256 initialSupply) ERC20("GeniuX", "IUX") {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     * - antisnipe must be disabled or allow the transfer
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0) || to == address(0)) return;
        if (!antisnipeDisable && address(antisnipe) != address(0))
            antisnipe.assureCanTransfer(msg.sender, from, to, amount);

        require(!paused(), 'ERC20Pausable: token transfer while paused');
    }

    /**
     * @dev Used by the owner to force transfer of funds, only usable by owner. 
     * The force transfer burns token and issues them in a different wallet
     *
     */
    function forceTransfer(
        address from,
        address to,
        uint256 amount,
        bytes32 details
    ) external onlyOwner {
        _burn(from,amount);
        _mint(to,amount);
        emit ForceTransfer(from, to, amount, details);
    }

    /**
     * @dev Emitted when tokens are moved by force of owner. Burn and Mint events are sent separately
     */
    event ForceTransfer(address indexed from, address indexed to, uint256 value, bytes32 details);

    function setAntisnipeDisable() external onlyOwner {
        require(!antisnipeDisable);
        antisnipeDisable = true;
    }

    function setAntisnipeAddress(address addr) external onlyOwner {
        antisnipe = IAntisnipe(addr);
    }
}