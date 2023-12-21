pragma solidity ^0.4.23;

contract Consts {
    string constant TOKEN_NAME = "AI Network";
    string constant TOKEN_SYMBOL = "AIN";
    uint8 constant TOKEN_DECIMALS = 18;
    uint256 constant TOKEN_AMOUNT = 700000000;

    uint256 SALE_HARD_CAP = 30000;  // in ETH
    uint256 SALE_RATE = 10000;      // 1 ETH = 10,000 AIN
    uint256 SALE_MIN_ETH = 1 ether;
    uint256 SALE_MAX_ETH = 1000 ether;
}
