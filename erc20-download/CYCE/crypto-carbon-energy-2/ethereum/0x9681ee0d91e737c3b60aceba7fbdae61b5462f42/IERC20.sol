// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

// Abstract contract defining interface for an ERC20 token
abstract contract IERC20 {
    // Get the total supply of tokens
    function totalSupply() external view virtual returns (uint256);

    // Transfer specified number of tokens from caller to the `to` address
    function transfer(
        address to,
        uint256 tokens
    ) external virtual returns (bool);

    // Approve the `spender` address to spend the specified number of tokens on behalf of the caller
    function approve(
        address spender,
        uint256 tokens
    ) external virtual returns (bool);

    // Get the approved number of tokens for a `spender` address from the `tokenOwner` address
    function allowance(
        address tokenOwner,
        address spender
    ) external view virtual returns (uint256);

    // Transfer specified number of tokens from `from` address to the `to` address
    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) external virtual returns (bool);

    // Get the balance of tokens for an `account` address
    function balanceOf(address account) public view virtual returns (uint256);

    // Event emitted when tokens are transferred
    event Transfer(address indexed from, address indexed to, uint256 tokens);

    // Event emitted when an approval is made
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
}
