// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./AccessControlProxyPausable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";

contract TutellusERC20 is AccessControlProxyPausable, ERC20CappedUpgradeable {

    uint256 public burned;

    event Mint(address account, uint256 amount);
    event Burn(address account, uint256 amount);

    constructor(string memory name, string memory symbol, uint256 cap, address rolemanager) {
        __TutellusERC20_init(name, symbol, cap, rolemanager);
    }

    function __TutellusERC20_init(string memory name, string memory symbol, uint256 cap, address rolemanager) internal initializer {
        __AccessControlProxyPausable_init(rolemanager);
        __ERC20_init(name, symbol);
        __ERC20Capped_init(cap);
        __TutellusERC20_init_unchained();
    }

    function __TutellusERC20_init_unchained() internal initializer {
    }

    function _mint(address account, uint256 amount) virtual internal override {
        require(totalSupply() + burned + amount <= cap(), "TutellusERC20: mint amount exceeds cap");
        super._mint(account, amount);
        emit Mint(account, amount);
    }

    function _burn(address account, uint256 amount) virtual internal override {
        burned += amount;
        super._burn(account, amount);
        emit Burn(account, amount);
    }

    function mint(address account, uint256 amount) public onlyRole(keccak256('MINTER_ROLE')) {
        _mint(account, amount);
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
}