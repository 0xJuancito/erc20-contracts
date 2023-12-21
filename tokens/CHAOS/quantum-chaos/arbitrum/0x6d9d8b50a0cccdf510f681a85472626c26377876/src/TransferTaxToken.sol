// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {ITransferTaxToken, IERC165} from "./interfaces/ITransferTaxToken.sol";
import {ILBRouter} from "joe-v2/interfaces/ILBRouter.sol";

/**
 * @title Transfer Tax Token
 * @author Trader Joe
 * @notice An ERC20 token that has a transfer tax.
 * The tax is calculated as `amount * taxRate / PRECISION`, where `PRECISION = 1e18`.
 * The tax is deducted from the amount before the transfer and sent to the tax recipient.
 * The tax recipient and tax rate can be changed by the owner, as well as the exclusion status of accounts from tax.
 */
contract TransferTaxToken is ERC20, Ownable2Step, ERC165, ITransferTaxToken {
    using Math for uint256;

    uint256 internal constant _PRECISION = 1e18;

    /**
     * @dev The exclusion status of accounts from transfer tax. Each new status must be a power of 2.
     * This is done so that statuses that are a combination of other statuses are easily checkable with
     * bitwise operations and do not require iteration.
     */
    uint256 internal constant _EXCLUDED_NONE = 0; // 0b0000
    uint256 internal constant _EXCLUDED_FROM = 1 << 0; // 0b0001
    uint256 internal constant _EXCLUDED_TO = 1 << 1; // 0b0010
    uint256 internal constant _EXCLUDED_BOTH = _EXCLUDED_FROM | _EXCLUDED_TO; // 0b0011
    uint256 public maxWallet;
    uint256 public threshold = 250000e18;
    bool private inSwap;

    mapping(address => bool) public isDexAddress;
    /**
     * @dev The recipient and rate of the transfer tax.
     */

    address private _taxRecipient;
    uint96 private _taxRate;
    bool public isDegen = true;

    ILBRouter router;
    ILBRouter.Path path;
    /**
     * @dev The exclusion status of accounts from transfer tax.
     */
    mapping(address => uint256) private _excludedFromTax;
    mapping(address => bool) public _isExcludedMaxTransactionAmount;

    /**
     * @notice Constructor that initializes the token's name and symbol.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param owner The owner of the token.
     */
    constructor(
        string memory name,
        string memory symbol,
        address owner
    ) ERC20(name, symbol) {
        _transferOwnership(owner);
    }

    /**
     * @notice Returns the address of the transfer tax recipient.
     * @return The address of the transfer tax recipient.
     */
    function taxRecipient() public view virtual override returns (address) {
        return _taxRecipient;
    }

    /**
     * @notice Returns the transfer tax rate.
     * @return The transfer tax rate.
     */
    function taxRate() public view virtual override returns (uint256) {
        return _taxRate;
    }

    /**
     * @notice Returns true if the `interfaceId` is supported by this contract.
     * @param interfaceId The interface identifier.
     * @return True if the `interfaceId` is supported by this contract.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(ITransferTaxToken).interfaceId ||
            interfaceId == type(IERC20).interfaceId ||
            ERC165.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns:
     * - `0` if `account` is not excluded from transfer tax,
     * - `1` if `account` is excluded from transfer tax when sending to another account,
     * - `2` if `account` is excluded from transfer tax when receiving from another account,
     * - `3` if `account` is excluded from transfer tax on both sending and receiving,
     * @param account The account to check.
     * @return The exclusion status of `account` from transfer tax.
     */
    function excludedFromTax(
        address account
    ) public view virtual override returns (uint256) {
        return _excludedFromTax[account];
    }

    /**
     * @notice Sets the transfer tax recipient to `newTaxRecipient`.
     * @dev Only callable by the owner.
     * @param newTaxRecipient The new transfer tax recipient.
     */
    function setTaxRecipient(
        address newTaxRecipient
    ) public virtual override onlyOwner {
        _setTaxRecipient(newTaxRecipient);
    }

    /**
     * @notice Sets the transfer tax rate to `newTaxRate`.
     * @dev Only callable by the owner. The tax recipient must be set before setting the tax rate.
     * The tax rate must be less than or equal to 100% (1e18).
     * @param newTaxRate The new transfer tax rate.
     */
    function setTaxRate(uint256 newTaxRate) public virtual override onlyOwner {
        _setTaxRate(newTaxRate);
    }

    /**
     * @notice Sets the exclusion status of `account` from transfer tax.
     * @dev Only callable by the owner.
     * @param account The account to set the exclusion status of.
     * @param excludedStatus The new exclusion status of `account` from transfer tax.
     */
    function setExcludedFromTax(
        address account,
        uint256 excludedStatus
    ) public virtual override onlyOwner {
        _setExcludedFromTax(account, excludedStatus);
    }

    /**
     * @dev Sets the transfer tax recipient to `newTaxRecipient`.
     * @param newTaxRecipient The new transfer tax recipient.
     */
    function _setTaxRecipient(address newTaxRecipient) internal virtual {
        _taxRecipient = newTaxRecipient;

        emit TaxRecipientSet(newTaxRecipient);
    }

    /**
     * @dev Sets the transfer tax rate to `newTaxRate`.
     * @param newTaxRate The new transfer tax rate.
     */
    function _setTaxRate(uint256 newTaxRate) internal virtual {
        require(
            newTaxRate <= _PRECISION,
            "TransferTaxToken: tax rate exceeds 100%"
        );

        // SafeCast is not needed here since the tax rate is bound by PRECISION, which is strictly less than 2**96.
        _taxRate = uint96(newTaxRate);

        emit TaxRateSet(newTaxRate);
    }

    /**
     * @dev Sets the exclusion status of `account` from transfer tax.
     * @param account The account to set the exclusion status of.
     * @param excludedStatus The new exclusion status of `account` from transfer tax.
     */
    function _setExcludedFromTax(
        address account,
        uint256 excludedStatus
    ) internal virtual {
        require(
            excludedStatus <= _EXCLUDED_BOTH,
            "TransferTaxToken: invalid excluded status"
        );
        require(
            _excludedFromTax[account] != excludedStatus,
            "TransferTaxToken: same exclusion status"
        );

        _excludedFromTax[account] = excludedStatus;

        emit ExcludedFromTaxSet(account, excludedStatus);
    }

    function excludeFromMaxTransaction(
        address updAds,
        bool isEx
    ) external onlyOwner {
        require(updAds != address(0), "zero address");
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    function includeFromDexAddresss(
        address updAds,
        bool isEx
    ) external onlyOwner {
        require(updAds != address(0), "zero address");
        isDexAddress[updAds] = isEx;
    }

    /**
     * @dev Transfers `amount` tokens from `sender` to `recipient`.
     * Overrides ERC20's transfer function to include transfer tax.
     * @param sender The sender address.
     * @param recipient The recipient address.
     * @param amount The amount to transfer.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(isDegen, "Trading is not active.");
        require(
            sender != address(0) && recipient != address(0),
            "zero address"
        );

        if (maxWallet != 0) {
            if (!_isExcludedMaxTransactionAmount[recipient]) {
                require(
                    amount + balanceOf(recipient) <= maxWallet,
                    "Max wallet exceeded"
                );
            }
        }

        if (
            inSwap ||
            (excludedFromTax(sender) & _EXCLUDED_FROM == _EXCLUDED_FROM ||
                excludedFromTax(recipient) & _EXCLUDED_TO == _EXCLUDED_TO)
        ) {
            super._transfer(sender, recipient, amount);
        } else {
            uint256 taxAmount = amount.mulDiv(taxRate(), _PRECISION);
            uint256 amountAfterTax = amount - taxAmount;

            _transferTaxAmount(sender, taxRecipient(), taxAmount);
            if (amountAfterTax > 0)
                super._transfer(sender, recipient, amountAfterTax);
        }

        if (
            balanceOf(address(this)) >= threshold &&
            !inSwap &&
            !(isDexAddress[sender] || isDexAddress[recipient])
        ) {
            swapTokensForEth();
        }
    }

    function setDegen(bool _isDegen) external onlyOwner {
        isDegen = _isDegen;
    }

    function setRouter(ILBRouter _router) external onlyOwner {
        router = _router;
    }

    function setPath(ILBRouter.Path calldata _path) external onlyOwner {
        path = _path;
    }

    function setMaxWallet(uint256 _maxWallet) external onlyOwner {
        maxWallet = _maxWallet;
    }

    function setThreshold(uint256 _threshold) external onlyOwner {
        threshold = _threshold;
    }

    /**
     * @dev Handles the transfer of the `taxAmount` to the `recipient`.
     * If the `recipient` is the zero address, the `taxAmount` is instead burned.
     * @param sender The sender address.
     * @param recipient The tax recipient address (or zero address if burn).
     * @param taxAmount The amount to transfer as tax.
     */
    function _transferTaxAmount(
        address sender,
        address recipient,
        uint256 taxAmount
    ) internal virtual {
        if (taxAmount > 0) {
            if (recipient == address(0)) _burn(sender, taxAmount);
            else super._transfer(sender, recipient, taxAmount);
        }
    }

    function swapTokensForEth() internal {
        require(address(router) != address(0), "Invalid Router");

        inSwap = true;
        uint256 _balance = balanceOf(address(this));
        if (_balance > 0) {
            _approve(address(this), address(router), _balance);
            router.swapExactTokensForNATIVE(
                _balance,
                0,
                path,
                payable(address(this)),
                block.timestamp
            );
        }
        inSwap = false;
    }
}
