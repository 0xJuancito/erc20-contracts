//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GenericERC20 is ERC20 {

    uint256 public immutable amount = 1000000000; // equivalant to RIDE supply on Multiversx

    constructor(string memory tokenName, string memory tokenSymbol) ERC20(tokenName, tokenSymbol) {
        _mint(msg.sender, amount * (10**decimals()));
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
