// SPDX-License-Identifier: MIT
pragma solidity =0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FameErc20 is ERC20, ERC20Permit {
    uint256 private constant TOTAL_SUPPLY = 10_000_000_000 * 1e18;

    error UnmatchedArraysLength();
    error UnmatchedTotalDistribution();

    constructor(
        string memory name,
        string memory symbol,
        address[] memory addresses,
        uint256[] memory distribution
    )
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        uint256 totalAddresses = addresses.length;
        if(totalAddresses != distribution.length){
            revert UnmatchedArraysLength();
        }

        uint256 total;
        for (uint256 index; index < totalAddresses; ++index) {
            _mint(addresses[index], distribution[index]);
            total += distribution[index];
        }

        if(total != TOTAL_SUPPLY){
            revert UnmatchedTotalDistribution();
        }
    }


}