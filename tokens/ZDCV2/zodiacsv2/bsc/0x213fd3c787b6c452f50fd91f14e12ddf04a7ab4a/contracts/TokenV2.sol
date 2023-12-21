pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./Ownable.sol";

contract TokenV2 is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(0xB9f092f51E0A4ef1c2b364a6c2f3301E62f94865, 1000000000 * 10**18);
    }
}
