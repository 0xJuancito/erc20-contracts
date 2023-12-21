// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./libraries/EnumerableUintToUintMapUpgradeable.sol";

import "./libraries/DigitsOfUint.sol";

contract Fiat24PriceList is Initializable, AccessControlUpgradeable {
    using DigitsOfUint for uint256;

    uint8 public constant MERCHANTDIGIT = 8;
    uint8 public constant MAXDIGITFORSALE = 5;

    function initialize() public initializer {
        __AccessControl_init_unchained();
    }

    function getPrice(uint256 accountNumber) external pure returns(uint256) {
        bool merchantAccountId = accountNumber.hasFirstDigit(MERCHANTDIGIT);
        // 1-8 => F24 1'500'000.00
        if(accountNumber >= 1 && accountNumber <= 8) {
            return 150000000;
        // 10-89 => F24 150'000.00
        } else if(accountNumber >= 10 && accountNumber <= 89) {
            return 15000000;
        // 100-899 => F24 15'000.00
        } else if (accountNumber >= 100 && accountNumber <= 899) {
            return 1500000;
        // 1000-8999 => F24 1'500.00
        } else if (accountNumber >= 1000 && accountNumber <= 8999) {
            return 150000;
        // account number of digits > 5 and merchant account => F24 500.00
        } else if(merchantAccountId) {
            return 50000;
        // number not available for sale
        } else {
            return 0;
        }
    }
}