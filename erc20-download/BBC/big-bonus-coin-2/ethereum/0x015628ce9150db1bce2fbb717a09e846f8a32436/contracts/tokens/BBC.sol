// SPDX-License-Identifier: GPLv3
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract BBC is ERC20, Ownable, ERC20Burnable {
    constructor() ERC20("Big Bonus Coin", "BBC") {
        _mint(msg.sender, 98521 ether);
    }

    /// @notice Creates `_amount` token to token address. Must only be called by the owner (MasterChef).
    function mint(uint256 _amount) public onlyOwner returns (bool) {
        return mintFor(msg.sender, _amount);
    }

    function mintFor(
        address _address,
        uint256 _amount
    ) public onlyOwner returns (bool) {
        _mint(_address, _amount);
        return true;
    }

    // Safe transfer function, just in case if rounding error causes pool to not have enough tokens.
    function safeTotalTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 balance = balanceOf(address(this));
        if (_amount > balance) {
            _transfer(address(this), _to, balance);
        } else {
            _transfer(address(this), _to, _amount);
        }
    }
}
