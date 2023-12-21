// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

interface ITransferTaxToken is IERC165 {
    event TaxRecipientSet(address indexed taxRecipient);

    event TaxRateSet(uint256 taxRate);

    event ExcludedFromTaxSet(address indexed account, uint256 excludedStatus);

    function taxRecipient() external view returns (address);

    function taxRate() external view returns (uint256);

    function excludedFromTax(address account) external view returns (uint256);

    function setTaxRate(uint256 taxRate) external;

    function setTaxRecipient(address taxRecipient) external;

    function setExcludedFromTax(address account, uint256 excludedStatus) external;
}
