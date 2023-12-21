// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20FlashMintUpgradeable.sol";

import "../roles/MinterRole.sol";

/// @title Mintable Contract
/// @notice Only administrators can mint tokens
/// @dev Enables increasing a balance by minting tokens
contract Mintable is
    ERC20FlashMintUpgradeable,
    MinterRole,
    ReentrancyGuardUpgradeable
{
    event Mint(address indexed minter, address indexed to, uint256 amount);

    uint256 public flashMintFee = 0;
    address public flashMintFeeReceiver;

    bool public isFlashMintEnabled = false;

    bytes32 public constant _RETURN_VALUE =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @notice Only administrators should be allowed to mint on behalf of another account
    /// @dev Mint a quantity of token in an account, increasing the balance
    /// @param minter Designated to be allowed to mint account tokens
    /// @param to The account tokens will be increased to
    /// @param amount The number of tokens to add to a balance
    function _mint(
        address minter,
        address to,
        uint256 amount
    ) internal returns (bool) {
        ERC20Upgradeable._mint(to, amount);
        emit Mint(minter, to, amount);
        return true;
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Enable or disable the flash mint functionality
    /// @param enabled A boolean flag that enables tokens to be flash minted
    function _setFlashMintEnabled(bool enabled) internal {
        isFlashMintEnabled = enabled;
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Sets the address that will receive fees of flash mints
    /// @param receiver The account that will receive flash mint fees
    function _setFlashMintFeeReceiver(address receiver) internal {
        flashMintFeeReceiver = receiver;
    }

    /// @dev Allow Owners to mint tokens to valid addresses
    /// @param account The account tokens will be added to
    /// @param amount The number of tokens to add to a balance
    function mint(address account, uint256 amount)
        public
        virtual
        onlyMinter
        returns (bool)
    {
        return Mintable._mint(msg.sender, account, amount);
    }

    /// @dev Public function to set the fee paid by the borrower for a flash mint
    /// @param fee The number of tokens that will cost to flash mint
    function setFlashMintFee(uint256 fee) external onlyMinter {
        flashMintFee = fee;
    }

    /// @dev Public function to enable or disable the flash mint functionality
    /// @param enabled A boolean flag that enables tokens to be flash minted
    function setFlashMintEnabled(bool enabled) external onlyMinter {
        _setFlashMintEnabled(enabled);
    }

    /// @dev Public function to update the receiver of the fee paid for a flash mint
    /// @param receiver The account that will receive flash mint fees
    function setFlashMintFeeReceiver(address receiver) external onlyMinter {
        _setFlashMintFeeReceiver(receiver);
    }

    /// @dev Public function that returns the fee set for a flash mint
    /// @param token The token to be flash loaned
    /// @return The fees applied to the corresponding flash loan
    function flashFee(address token, uint256)
        public
        view
        override
        returns (uint256)
    {
        require(token == address(this), "ERC20FlashMint: wrong token");

        return flashMintFee;
    }

    /// @dev Performs a flash loan. New tokens are minted and sent to the
    /// `receiver`, who is required to implement the {IERC3156FlashBorrower}
    /// interface. By the end of the flash loan, the receiver is expected to own
    /// amount + fee tokens so that the fee can be sent to the fee receiver and the
    /// amount minted should be burned before the transaction completes
    /// @param receiver The receiver of the flash loan. Should implement the
    /// {IERC3156FlashBorrower.onFlashLoan} interface
    /// @param token The token to be flash loaned. Only `address(this)` is
    /// supported
    /// @param amount The amount of tokens to be loaned
    /// @param data An arbitrary datafield that is passed to the receiver
    /// @return `true` if the flash loan was successful
    function flashLoan(
        IERC3156FlashBorrowerUpgradeable receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) public override nonReentrant returns (bool) {
        require(isFlashMintEnabled, "flash mint is disabled");

        uint256 fee = flashFee(token, amount);
        _mint(address(receiver), amount);

        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) ==
                _RETURN_VALUE,
            "ERC20FlashMint: invalid return value"
        );
        uint256 currentAllowance = allowance(address(receiver), address(this));
        require(
            currentAllowance >= amount + fee,
            "ERC20FlashMint: allowance does not allow refund"
        );

        _transfer(address(receiver), flashMintFeeReceiver, fee);
        _approve(
            address(receiver),
            address(this),
            currentAllowance - amount - fee
        );
        _burn(address(receiver), amount);

        return true;
    }

    uint256[47] private __gap;
}
