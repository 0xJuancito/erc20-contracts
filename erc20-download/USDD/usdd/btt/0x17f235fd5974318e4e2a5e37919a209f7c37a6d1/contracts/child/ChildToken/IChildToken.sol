pragma solidity 0.6.6;

interface IChildToken {
    event WithdrawTo(address indexed from, address indexed to, uint256 amount);
    function deposit(address user, bytes calldata depositData) external;
}
