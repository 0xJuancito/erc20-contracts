// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IERC677 is IERC20 {
    function transferAndCall(address recipient, uint amount, bytes memory data) external returns (bool success);
    
    event Transfer(address indexed from, address indexed to, uint value, bytes data);
}

interface IERC677Receiver {
    function onTokenTransfer(address sender, uint value, bytes memory data) external;
}
