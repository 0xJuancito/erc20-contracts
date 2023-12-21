// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";

/// @notice Base contract for token bridged from original chain. Can only be minted from a bridge controller
abstract contract BaseBridgedERC20 is OwnableUpgradeable, PausableUpgradeable, ERC20Upgradeable {
    address public bridgeController;

    function __BaseBridgedERC20_init(string memory name_, string memory symbol_) internal {
        __Ownable_init();
        __Pausable_init();
        __ERC20_init(name_, symbol_);
    }

    function mint(address _to, uint256 _amount) external whenNotPaused {
        require(msg.sender == bridgeController, "!minter");
        _mint(_to, _amount);
        emit Minted(_to, _amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function setBridgeController(address _controller) external onlyOwner {
        require(_controller != address(0));
        bridgeController = _controller;
        emit BridgeControllerSet(_controller);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    event BridgeControllerSet(address _controller);
    event Minted(address _to, uint256 _amount);
}
