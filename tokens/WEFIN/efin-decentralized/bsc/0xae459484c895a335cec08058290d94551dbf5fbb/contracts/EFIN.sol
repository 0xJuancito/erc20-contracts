//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

// Contracts
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract WEFIN is ERC20Burnable, AccessControl {
    /* Contants */

    /*
        @dev The admin role for the minter role is the default in the AccessControl.sol file.
        @dev See more info AccessControl#DEFAULT_ADMIN_ROLE
     */
    bytes32 private constant MINTER_ROLE = keccak256("MinterRole");

    string private constant NAME = "Wrapped EFIN";
    string private constant SYMBOL = "WEFIN";
    uint8 private constant DECIMALS = 8;

    /* Modifiers */

    modifier onlyMinter(address account) {
        require(hasRole(MINTER_ROLE, account), "SENDER_HASNT_MINTER_ROLE");
        _;
    }

    constructor() public ERC20(NAME, SYMBOL) {
        _setupDecimals(DECIMALS);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) external onlyMinter(_msgSender()) {
        _mint(to, amount);
    }
}
