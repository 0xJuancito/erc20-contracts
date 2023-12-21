// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BTAFVesting is Ownable {
    using SafeERC20 for IERC20;

    // ERC20 basic token contract being held
    IERC20 private immutable _token;
    address private immutable _self;

    mapping(address => uint256) private _balances;

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    constructor(address token_) {
        _token = IERC20(token_);
        _self = address(this);
    }

    /**
     * @return the token being held.
     */
    function token() public view returns (IERC20) {
        return IERC20(_token);
    }

    /** 
    * @notice Deposit tokens to the contract, to be held for the sender
    */
    function vest(uint256 amount) public {
        token().safeTransferFrom(msg.sender, _self, amount);
        _balances[msg.sender] += amount;

        emit Vested(amount, msg.sender);
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary. Fail if not enough tokens.
     * @param amount The amount of tokens to be released.
     */
    function release(uint256 amount) public {
        uint256 balance = balanceOf(msg.sender);
        require(amount >= balance, "release: Insufficient balance");

        _balances[msg.sender] -= amount;
        token().safeTransfer(msg.sender, amount);

        emit Released(amount, msg.sender);
    }

    event Released(uint256 amount, address indexed beneficiary);
    event Vested(uint256 amount, address indexed beneficiary);
}
