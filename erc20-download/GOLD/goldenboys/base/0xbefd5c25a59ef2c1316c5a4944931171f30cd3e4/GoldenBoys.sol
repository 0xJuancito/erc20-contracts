// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "ERC20.sol";
import "Ownable.sol";
import "SafeERC20.sol";

// Welcome to GoldenBoys Club
// Own it, make Yourself a GoldenBoy!
// Its Time to Shine


contract GoldenBoys is ERC20, Ownable {
    uint8 private constant _decimals = 18;
    uint256 public constant maxSupply = 1000000 * 10 ** _decimals;

    event ERC20Swept(address indexed token, address payee, uint256 amount);

    constructor() ERC20("GoldenBoys", "GOLD") {
        transferOwnership(0x36cc7B13029B5DEe4034745FB4F24034f3F2ffc6);
        // Whaling since 2013, Now Giving Back Some Gold!
    }


    function mint(address to, uint256 amount) external onlyOwner {//This lets the
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
    }

    /**
     * @notice Sweep the full contract's balance for a given ERC-20 token
     * @notice  Allows the owner to access tokens accidentally sent to the contract
   * @param token The ERC-20 token which needs to be swept
   * @param payee The address to pay
   */
    function sweep(address token, address payee) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        emit ERC20Swept(token, payee, balance);
        SafeERC20.safeTransfer(IERC20(token), payee, balance);
    }
}
