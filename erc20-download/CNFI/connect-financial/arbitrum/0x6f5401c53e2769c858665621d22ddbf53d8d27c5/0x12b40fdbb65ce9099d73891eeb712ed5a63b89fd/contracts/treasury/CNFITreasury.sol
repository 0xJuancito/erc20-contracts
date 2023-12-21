// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract CNFITreasury is OwnableUpgradeable {
    address relayer;
    modifier onlyRelayer {
        require(msg.sender == owner() || msg.sender == relayer, "unauthorized");
        _;
    }

    function initialize(address _relayer) public {
        __Ownable_init_unchained();
        relayer = _relayer;
    }

    function transferToken(
        address token,
        address to,
        uint256 amount
    ) public onlyRelayer returns (bool) {
        IERC20Upgradeable(token).transfer(to, amount);
    }
}
