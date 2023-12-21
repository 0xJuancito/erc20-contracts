// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "./ImportsManager.sol";

/// @title Rand.network ERC20 Token contract
/// @author @adradr - Adrian Lenard
/// @notice Default implementation of the OpenZeppelin ERC20 standard to be used for the RND token
contract RandToken is
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ImportsManager
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    uint8 private decimal;

    /// @notice Initializer allow proxy scheme
    /// @dev For upgradability its necessary to use initialize instead of simple constructor
    /// @param name_ Name of the token like `Rand Token ERC20`
    /// @param symbol_ Short symbol like `RND`
    /// @param _initialSupply Total supply to mint initially like `200e6`
    /// @param _registry is the address of address registry
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 _initialSupply,
        uint8 _decimal,
        IAddressRegistry _registry
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Burnable_init();
        __ImportsManager_init();

        REGISTRY = _registry;
        decimal = _decimal;

        address _multisigVault = REGISTRY.getAddressOf(REGISTRY.MULTISIG());
        _grantRole(DEFAULT_ADMIN_ROLE, _multisigVault);
        _grantRole(PAUSER_ROLE, _multisigVault);
        _grantRole(MINTER_ROLE, _multisigVault);
        _mint(_multisigVault, _initialSupply * 10 ** decimals());
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(
        address to,
        uint256 amount
    ) public whenNotPaused onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return decimal;
    }

    /// @inheritdoc	ERC20Upgradeable
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
