pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YAETokenBSC is ERC20Burnable {
    // Wrapped BSC token for Cryptonovae (YAE) on Ethereum
    // Official ETH contract: 0x4ee438be38f8682abb089f2bfea48851c5e71eaf
    constructor() ERC20("Cryptonovae", "YAE") {
        _mint(address(0xA53c5dB7dC0f541C013f4a172D46381EAC00A60E), 100000000e18);
    }
}
