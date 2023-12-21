// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ITransferDoubleTaxToken} from "./ITransferDoubleTaxToken.sol";

interface ITransferTripleTaxToken is ITransferDoubleTaxToken {
    event ThirdTaxRecipientSet(address indexed thirdTaxRecipient);

    event ShareForThirdTaxRecipientSet(uint256 shareForThirdTaxRecipient);

    function thirdTaxRecipient() external view returns (address);

    function shareForThirdTaxRecipient() external view returns (uint256);

    function setThirdTaxRecipient(address newThirdTaxRecipient) external;

    function setShareForThirdTaxRecipient(uint256 newShareForThirdTaxRecipient) external;
}
