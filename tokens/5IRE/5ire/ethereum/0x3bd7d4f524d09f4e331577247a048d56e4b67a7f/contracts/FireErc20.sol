//SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @author 5ire Team [5ire](https://github.com/5ire-org)
 */
contract FireErc20 is ERC20 {
    uint256 private constant _INITIAL_SUPPLY = 1500000000 * 1e18;
    uint256 private constant _DISTRIBUTION_PERCENT_BASE = 10000000000; // lowest possible percent value is 0.00000001%

    constructor(
        string memory _name,
        string memory _symbol,
        address[] memory _addresses,
        uint256[] memory _distributionPercents
    ) ERC20(_name, _symbol) {
        uint256 totalAddresses = _addresses.length;
        require(
            totalAddresses == _distributionPercents.length,
            "5ire: Inequal array"
        );

        uint256 percentSum;
        for (uint256 index; index < totalAddresses; ++index) {
            percentSum += _distributionPercents[index];
            require(_addresses[index] != address(0), "5ire: zero address");
            _mint(
                _addresses[index],
                (_INITIAL_SUPPLY * _distributionPercents[index]) /
                    _DISTRIBUTION_PERCENT_BASE
            );
        }

        require(
            percentSum == _DISTRIBUTION_PERCENT_BASE,
            "5ire: bad percentages"
        );
    }
}
