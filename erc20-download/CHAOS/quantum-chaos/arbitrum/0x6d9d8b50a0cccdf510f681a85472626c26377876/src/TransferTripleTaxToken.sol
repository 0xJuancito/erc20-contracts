// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {TransferDoubleTaxToken, TransferTaxToken, ITransferDoubleTaxToken, IERC165} from "./TransferDoubleTaxToken.sol";
import {ITransferTripleTaxToken} from "./interfaces/ITransferTripleTaxToken.sol";

/**
 * @title Transfer Triple Tax Token
 * @author Trader Joe
 * @notice An ERC20 token that has a transfer tax.
 * The tax is calculated as `amount * taxRate / PRECISION`, where `PRECISION = 1e18`.
 * The tax is deducted from the amount before the transfer and sent to the tax recipient.
 * The tax recipients and tax rate can be changed by the owner, as well as the exclusion status of accounts from tax.
 * The second and third recipient will receive fees according to the shares set by the owner.
 */
contract TransferTripleTaxToken is
    TransferDoubleTaxToken,
    ITransferTripleTaxToken
{
    using Math for uint256;

    /**
     * @dev The third recipient and the share of the transfer tax for the third recipient.
     */
    address private _thirdTaxRecipient;
    uint96 private _shareForThirdTaxRecipient;

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
    ) TransferDoubleTaxToken(name, symbol, owner) {}

    /**
     * @notice Returns the address of the third transfer tax recipient.
     * @return The address of the third transfer tax recipient.
     */
    function thirdTaxRecipient()
        public
        view
        virtual
        override
        returns (address)
    {
        return _thirdTaxRecipient;
    }

    /**
     * @notice Returns the share of the transfer tax for the third recipient.
     * @return The share of the transfer tax for the third recipient.
     */
    function shareForThirdTaxRecipient()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _shareForThirdTaxRecipient;
    }

    /**
     * @notice Returns true if the `interfaceId` is supported by this contract.
     * @param interfaceId The interface identifier.
     * @return True if the `interfaceId` is supported by this contract.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(TransferDoubleTaxToken, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(ITransferTripleTaxToken).interfaceId ||
            TransferDoubleTaxToken.supportsInterface(interfaceId);
    }

    /**
     * @notice Sets the third transfer tax recipient.
     * @dev Only callable by the owner.
     * @param newThirdTaxRecipient The new third transfer tax recipient.
     */
    function setThirdTaxRecipient(
        address newThirdTaxRecipient
    ) public virtual override onlyOwner {
        _thirdTaxRecipient = newThirdTaxRecipient;

        emit ThirdTaxRecipientSet(newThirdTaxRecipient);
    }

    /**
     * @notice Sets the share of the transfer tax for the second recipient.
     * @dev Only callable by the owner.
     * Overrides the parent contract to verify that the sum of the shares is less than or equal to 100% (_PRECISION).
     * @param newShareForSecondRecipient The new share of the transfer tax for the second recipient.
     */
    function setShareForSecondTaxRecipient(
        uint256 newShareForSecondRecipient
    )
        public
        virtual
        override(TransferDoubleTaxToken, ITransferDoubleTaxToken)
        onlyOwner
    {
        require(
            newShareForSecondRecipient <= _PRECISION,
            "TransferTripleTaxToken: invalid share"
        );

        TransferDoubleTaxToken._setShareForSecondTaxRecipient(
            uint96(newShareForSecondRecipient)
        );
    }

    /**
     * @notice Sets the share of the transfer tax for the third recipient.
     * @dev Only callable by the owner.
     * @param newShareForThirdRecipient The new share of the transfer tax for the third recipient.
     */
    function setShareForThirdTaxRecipient(
        uint256 newShareForThirdRecipient
    ) public virtual override onlyOwner {
        require(
            newShareForThirdRecipient <= _PRECISION,
            "TransferTripleTaxToken: invalid share"
        );

        _shareForThirdTaxRecipient = uint96(newShareForThirdRecipient);

        emit ShareForThirdTaxRecipientSet(newShareForThirdRecipient);
    }

    /**
     * @notice Overrides the parent `_transferTaxAmount` function to split the tax between the two recipients.
     * @param sender The sender of the tokens.
     * @param firstTaxRecipient The first recipient of the tokens.
     * @param totalTaxAmount The total tax amount that will be split between the two tax recipients.
     */
    function _transferTaxAmount(
        address sender,
        address firstTaxRecipient,
        uint256 totalTaxAmount
    ) internal virtual override {
        uint256 amountForThirdTaxRecipient = totalTaxAmount.mulDiv(
            shareForThirdTaxRecipient(),
            _PRECISION
        );

        TransferTaxToken._transferTaxAmount(
            sender,
            thirdTaxRecipient(),
            amountForThirdTaxRecipient
        );

        uint256 amountForRemainingTaxRecipient = totalTaxAmount -
            amountForThirdTaxRecipient;

        TransferTaxToken._transferTaxAmount(
            sender,
            address(this),
            amountForRemainingTaxRecipient
        );
    }

    function transferETH() external onlyOwner {
        uint256 balance = address(this).balance;

        uint256 amountForSecondTaxRecipient = balance.mulDiv(
            shareForSecondTaxRecipient(),
            _PRECISION
        );
        (bool sent2, ) = secondTaxRecipient().call{
            value: amountForSecondTaxRecipient
        }("");
        require(sent2, "Failed to send Ether");

        (bool sent1, ) = taxRecipient().call{value: address(this).balance}("");

        require(sent1, "Failed to send Ether");
    }

    receive() external payable {}
}
