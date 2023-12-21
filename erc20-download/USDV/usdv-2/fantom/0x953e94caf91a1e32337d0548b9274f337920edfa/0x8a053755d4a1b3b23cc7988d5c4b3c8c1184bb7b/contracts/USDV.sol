// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title USDV
 * @notice USDV stable coin contract
 */
contract USDV is Initializable, ERC20Upgradeable, AccessControlUpgradeable {
    bytes32 public constant MINT_BURN_ROLE = keccak256("MINT_BURN_ROLE");
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @dev instead of constructor because of Upgradeable architecture
     */
    function initialize() external initializer {
        __ERC20_init("USDV", "USDV");
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice {OpenZeppelin-ERC20} mint tokens for {to} in {amount}
     * @dev usage limited {MINT_BURN_ROLE} role
     * @param to tokens destination address
     * @param amount amount of minting
     */
    function mint(address to, uint256 amount) external onlyRole(MINT_BURN_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice {OpenZeppelin-ERC20} burn tokens from {account} in {amount}
     * @dev usage limited {MINT_BURN_ROLE} role
     * @param account token owner address
     * @param amount amount of burning
     */
    function burn(address account, uint256 amount) external onlyRole(MINT_BURN_ROLE) {
        _burn(account, amount);
    }
}