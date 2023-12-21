pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor() public  ERC20("TrustFi Network Token", "TFI") {
        _mint(0xE15CD3FB9315e72A319f80cf7442815c5f3618Ec, 10 ** 8 * 10 ** 18);
    }
}
