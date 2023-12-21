// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {L2StandardERC20} from "@eth-optimism/contracts/standards/L2StandardERC20.sol";

contract L2CustomERC20 is ERC20Permit, L2StandardERC20 {
    constructor(
        address _l2Bridge,
        address _l1Token,
        string memory _name,
        string memory _symbol
    ) ERC20Permit(_name) L2StandardERC20(_l2Bridge, _l1Token, _name, _symbol) {}
}
