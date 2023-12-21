//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

import {ISparta, IERC20Decimals} from "./interfaces/ISparta.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Sparta is ISparta, ERC20 {
    uint256 public constant MAX_SUPPLY = 100000000 ether;

    constructor(address _admin) ERC20("SPARTA", "SPARTA") {
        _mint(_admin, MAX_SUPPLY);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    function decimals()
        public
        view
        override(IERC20Decimals, ERC20)
        returns (uint8)
    {
        return ERC20.decimals();
    }
}
