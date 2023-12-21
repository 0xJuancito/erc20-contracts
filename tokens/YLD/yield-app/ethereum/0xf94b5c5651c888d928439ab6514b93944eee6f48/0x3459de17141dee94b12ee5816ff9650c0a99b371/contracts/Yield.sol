// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.5;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20PausableUpgradeable.sol";

contract Yield is
Initializable,
ContextUpgradeable,
AccessControlUpgradeable,
ERC20CappedUpgradeable,
ERC20BurnableUpgradeable,
ERC20PausableUpgradeable
{

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function initializeToken(uint256 totalSupply, address multisig) public virtual initializer
    {
        __Context_init_unchained();
        __ERC20_init_unchained("Yield", "YLD");
        __ERC20Capped_init_unchained(totalSupply);
        __ERC20Burnable_init_unchained();
        __ERC20Pausable_init_unchained();
        __Pausable_init_unchained();
        __AccessControl_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, multisig);
        _setupRole(MINTER_ROLE, multisig);
        _setupRole(PAUSER_ROLE, multisig);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal virtual override(ERC20CappedUpgradeable, ERC20PausableUpgradeable, ERC20Upgradeable)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function pause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "Caller is not a pauser");
        _pause();
    }

    function unpause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "Caller is not a pauser");
        _unpause();
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "Caller is not a minter");
        _mint(to, amount);
    }
}


