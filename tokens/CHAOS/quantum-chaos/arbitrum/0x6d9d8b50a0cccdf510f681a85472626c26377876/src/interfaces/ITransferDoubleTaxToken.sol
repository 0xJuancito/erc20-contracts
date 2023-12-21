// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

interface ITransferDoubleTaxToken is IERC165 {
    event SecondTaxRecipientSet(address indexed secondTaxRecipient);

    event ShareForSecondTaxRecipientSet(uint256 shareForSecondTaxRecipient);

    function secondTaxRecipient() external view returns (address);

    function shareForSecondTaxRecipient() external view returns (uint256);

    function setSecondTaxRecipient(address newSecondTaxRecipient) external;

    function setShareForSecondTaxRecipient(uint256 newShareForSecondTaxRecipient) external;
}
