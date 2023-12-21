// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IllegalArgument, IllegalState, Unauthorized} from "./base/Errors.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";

import "./libraries/Checker.sol";

/// @title  SavvyToken
/// @author Savvy DeFi
///
/// @notice This is the contract for the Savvy's synthetic token (svTokens).
contract SavvySyntheticToken is
    AccessControl,
    ReentrancyGuard,
    ERC20,
    IERC3156FlashLender
{
    /// @notice The identifier of the role which maintains other roles.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    /// @notice The identifier of the role which allows accounts to mint tokens.
    bytes32 public constant SENTINEL_ROLE = keccak256("SENTINEL");

    /// @notice The indentifier of the role which allows
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");

    /// @notice The expected return value from a flash mint receiver.
    bytes32 public constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @notice The maximum number of basis points needed to represent 100%.
    uint256 public constant BPS = 10000;

    /// @notice A set of addresses which are paused from minting new tokens.
    mapping(address => bool) public paused;

    /// @notice Fee for flash minting.
    uint256 public flashMintFee;

    /// @notice Max flash mint amount.
    uint256 public maxFlashLoanAmount;

    /// @notice An event which is emitted when a minter is paused from minting.
    ///
    /// @param minter The address of the minter which was paused.
    /// @param state  A flag indicating if the savvy is paused or unpaused.
    event Paused(address minter, bool state);

    /// @notice An event which is emitted when the flash mint fee is updated.
    ///
    /// @param fee The new flash mint fee.
    event SetFlashMintFee(uint256 fee);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _flashFee
    ) ERC20(_name, _symbol) {
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(SENTINEL_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _setRoleAdmin(SENTINEL_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        setFlashFee(_flashFee);
    }

    modifier ensureUnpaused() {
        Checker.checkState(!paused[msg.sender], "sender is paused to mint");
        _;
    }

    /// @dev A modifier which checks that the caller has the admin role.
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Unauthorized admin");
        _;
    }

    /// @dev A modifier which checks that the caller has the sentinel role.
    modifier onlySentinel() {
        require(hasRole(SENTINEL_ROLE, msg.sender), "Unauthorized sentinel");
        _;
    }

    /// @dev A modifier which checks if the caller is allowed to min.
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Unauthorized minter");
        _;
    }

    /// @notice Sets the flash minting fee.
    ///
    /// @notice This function reverts if `msg.sender` is not an admin.
    ///
    /// @param newFee The new flash mint fee.
    function setFlashFee(uint256 newFee) public onlyAdmin {
        Checker.checkArgument(newFee <= BPS, "invalid fee");
        flashMintFee = newFee;
        emit SetFlashMintFee(flashMintFee);
    }

    /// @notice Mints tokens to the `recipient.`
    ///
    /// @notice This function reverts if `msg.sender` is not allowed to mint.
    /// @notice This function reverts if `msg.sender` is paused from minting.
    /// @notice This function reverts if `msg.sender` has exceeded the token's mintable ceiling.
    ///
    /// @param recipient The address to mint the tokens to.
    /// @param amount    The amount of tokens to mint.
    function mint(
        address recipient,
        uint256 amount
    ) external onlyMinter ensureUnpaused {
        Checker.checkArgument(amount > 0, "zero mint amount");

        _mint(recipient, amount);
    }

    /// @notice Grants `minter` permission to mint.
    ///
    /// @notice This function reverts if `msg.sender` is not an admin.
    ///
    /// @param minter The address to permit to mint.
    /// @param state  A flag indicating if the minter should be able to mint.
    function setAllowedMinter(address minter, bool state) external onlyAdmin {
        Checker.checkArgument(minter != address(0), "zero minter address");
        if (state) {
            _grantRole(MINTER_ROLE, minter);
        } else {
            _revokeRole(MINTER_ROLE, minter);
        }
    }

    /// @notice Sets `sentinel` as a sentinel.
    ///
    /// @notice This function reverts if `msg.sender` is not an admin.
    ///
    /// @param sentinel The address to set as a sentinel.
    function setSentinel(address sentinel) external onlyAdmin {
        _grantRole(SENTINEL_ROLE, sentinel);
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
    /// @param amount  The address of the tokens that are being burned.
    function burnFrom(address account, uint256 amount) external {
        Checker.checkState(
            allowance(account, msg.sender) >= amount,
            "insufficient allowance"
        );
        uint256 newAllowance = allowance(account, msg.sender) - amount;

        _approve(account, msg.sender, newAllowance);
        _burn(account, amount);
    }

    /// @notice Adjusts the maximum flashloan amount.
    ///
    /// @param _maxFlashLoanAmount The maximum flashloan amount.
    function setMaxFlashLoan(uint _maxFlashLoanAmount) external onlyAdmin {
        maxFlashLoanAmount = _maxFlashLoanAmount;
    }

    /// @notice Gets the maximum flash loan amount of a token.
    ///
    /// @param token The address of the token.
    ///
    /// @return The maximum amount of `token` that can be flashed loaned.
    function maxFlashLoan(
        address token
    ) public view override returns (uint256) {
        if (token != address(this)) {
            return 0;
        }
        return maxFlashLoanAmount;
    }

    /// @notice Gets the fee for a flash loan of `amount` of `token`.
    ///
    /// @param token The address of the `token`.
    /// @param amount The amount of `token` to flash mint.
    ///
    /// @return The flash loan fee.
    function flashFee(
        address token,
        uint256 amount
    ) public view override returns (uint256) {
        require(token == address(this), "Not a valid flash fee token");
        return (amount * flashMintFee) / BPS;
    }

    /// @notice Performs a flash mint (called flash loan to confirm with ERC3156 standard).
    ///
    /// @param receiver The address which will receive the flash minted tokens.
    /// @param token    The address of the token to flash mint.
    /// @param amount   The amount to flash mint.
    /// @param data     ABI encoded data to pass to the receiver.
    ///
    /// @return If the flash loan was successful.
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override nonReentrant returns (bool) {
        Checker.checkArgument(token == address(this), "invalid token address");
        Checker.checkArgument(
            amount <= maxFlashLoan(token),
            "token amount exceeds max flash loan amount"
        );
        uint256 fee = flashFee(token, amount);

        if (amount > 0) {
            _mint(address(receiver), amount);
        }

        Checker.checkState(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) ==
                CALLBACK_SUCCESS,
            "flash loan failed"
        );

        _burn(address(receiver), amount + fee); // Will throw error if not enough to burn

        return true;
    }

    uint256[100] private __gap;
}
