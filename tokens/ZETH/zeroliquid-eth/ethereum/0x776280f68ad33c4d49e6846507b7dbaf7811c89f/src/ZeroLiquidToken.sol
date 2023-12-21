// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { IllegalState, Unauthorized } from "./base/Errors.sol";

/// @title  ZeroLiquidToken
/// @author ZeroLiquid
///
/// @notice This is the contract for zeroliquid synthetic debt token.
contract ZeroLiquidToken is AccessControl, ERC20 {
    /// @notice The identifier of the role which maintains other roles.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    /// @notice The identifier of the role which allows accounts to mint tokens.
    bytes32 public constant SENTINEL_ROLE = keccak256("SENTINEL");

    /// @notice A set of addresses which are whitelisted for minting new tokens.
    mapping(address => bool) public whitelisted;

    /// @notice A set of addresses which are paused from minting new tokens.
    mapping(address => bool) public paused;

    /// @notice An event which is emitted when a minter is paused from minting.
    ///
    /// @param minter The address of the minter which was paused.
    /// @param state  A flag indicating if the zeroliquid is paused or unpaused.
    event Paused(address minter, bool state);

    constructor(string memory _name, string memory _symbol, address _admin) ERC20(_name, _symbol) {
        _setupRole(ADMIN_ROLE, _admin);
        _setupRole(SENTINEL_ROLE, _admin);
        _setRoleAdmin(SENTINEL_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    /// @dev A modifier which checks that the caller has the admin role.
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    /// @dev A modifier which checks that the caller has the sentinel role.
    modifier onlySentinel() {
        if (!hasRole(SENTINEL_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    /// @dev A modifier which checks if whitelisted for minting.
    modifier onlyWhitelisted() {
        if (!whitelisted[msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Mints tokens to `a recipient.`
    ///
    /// @notice This function reverts if `msg.sender` is not whitelisted.
    /// @notice This function reverts if `msg.sender` is paused.
    ///
    /// @param recipient The address to mint the tokens to.
    /// @param amount    The amount of tokens to mint.
    function mint(address recipient, uint256 amount) external onlyWhitelisted {
        if (paused[msg.sender]) {
            revert IllegalState();
        }

        _mint(recipient, amount);
    }

    /// @notice Sets `minter` as whitelisted to mint.
    ///
    /// @notice This function reverts if `msg.sender` is not an admin.
    ///
    /// @param minter The account to permit to mint.
    /// @param state  A flag indicating if the minter should be able to mint.
    function setWhitelist(address minter, bool state) external onlyAdmin {
        whitelisted[minter] = state;
    }

    /// @notice Sets `sentinel` as a sentinel.
    ///
    /// @notice This function reverts if `msg.sender` is not an admin.
    ///
    /// @param sentinel The address to set as a sentinel.
    function setSentinel(address sentinel) external onlyAdmin {
        _setupRole(SENTINEL_ROLE, sentinel);
    }

    /// @notice Pauses `minter` from minting tokens.
    ///
    /// @notice This function reverts if `msg.sender` is not a sentinel.
    ///
    /// @param minter The address to set as paused or unpaused.
    /// @param state  A flag indicating if the minter should be paused or unpaused.
    function pauseMinter(address minter, bool state) external onlySentinel {
        paused[minter] = state;
        emit Paused(minter, state);
    }

    /// @notice Burns `amount` tokens from `msg.sender`.
    ///
    /// @param amount The amount of tokens to be burned.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @dev Destroys `amount` tokens from `account`, deducting from the caller's allowance.
    ///
    /// @param account The address the burn tokens from.
    /// @param amount  The amount of tokens to burn.
    function burnFrom(address account, uint256 amount) external {
        uint256 newAllowance = allowance(account, msg.sender) - amount;

        _approve(account, msg.sender, newAllowance);
        _burn(account, amount);
    }
}
