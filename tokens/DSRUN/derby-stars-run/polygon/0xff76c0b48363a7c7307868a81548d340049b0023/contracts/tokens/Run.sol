//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IRun } from "./IRun.sol";

contract Run is ERC20Burnable, ERC20Capped, Ownable2Step, IRun {
    constructor(uint256 cap) ERC20("DerbyStarsRUN", "DSRUN") ERC20Capped(cap) {}

    function mint(uint256 amount) external onlyOwner {
        _mint(owner(), amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20Capped, ERC20) {
        super._mint(account, amount);
    }

    /**
     * @dev Perform transfer and emit event with given memo.
     */
    function transferWithMemo(address to, uint256 amount, string[] memory memo) external override {
        address from = msg.sender;
        _transfer(from, to, amount);
        emit TransferWithMemo(from, to, amount, memo);
    }

    /**
     * @dev Perform transferFrom and emit event with given memo.
     */
    function transferFromWithMemo(address from, address to, uint256 amount, string[] memory memo) external override {
        transferFrom(from, to, amount);
        emit TransferWithMemo(from, to, amount, memo);
    }
}
