// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MaxSupplyERC20Upgradeable is ERC20Upgradeable {
    uint256 private _maxSupply;

    function __initializeErc20(string memory name_, string memory symbol_, uint256 maxSupply_) public initializer {
        _maxSupply = maxSupply_;
        __ERC20_init(name_, symbol_);
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }


    function __mint(address account, uint256 amount) internal {
        require(totalSupply() + amount <= _maxSupply, "Max supply exceeded");
        // Check if max supply would be exceeded
        super._mint(account, amount);
        // Create the new tokens
    }
}
