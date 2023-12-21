// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libs/DateTime.sol";

/*
 * Vesting contract for BTAF monthly vesting.
 * The initial release date is set to 3 months after the contract is deployed.
 * After the release date has passed, calling release() will release the monthy amount of tokens,
 * and set the next release date to one month in the future.
 */

contract BTAFMonthlyVesting is Ownable {
    using SafeERC20 for IERC20;
    using BokkyPooBahsDateTimeLibrary for uint256;

    // ERC20 basic underlying token being held
    IERC20 private immutable _token;
    address private immutable _self;

    // Timestamp when the next token release is enabled
    uint256 private _nextReleaseDate;

    // Mapping of addresses to amounts of tokens vested
    mapping(address => uint256) private _balances;

    // Amount of tokens to be released each month
    uint256 public immutable amountPerMonth;

    constructor(address token_, uint256 amount_) {
        _token = IERC20(token_);
        _self = address(this);
        // Set the initial release date to 3 months after the contract is deployed
        _nextReleaseDate = BokkyPooBahsDateTimeLibrary.addMonths(
            block.timestamp,
            3
        );
        amountPerMonth = amount_ * (10**18); // Assumes 18 decimals
    }

    /**
     * @notice Get the tokens held for a given account
     * @param account The account to check
     * @return The amount of tokens held
     */

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @return the token being held.
     */
    function token() public view returns (IERC20) {
        return IERC20(_token);
    }

    /**
     * @notice Deposit tokens to the contract, to be held for a beneficiary
     */
    function vest(uint256 amount, address beneficiary) public {
        token().safeTransferFrom(msg.sender, _self, amount);
        _balances[beneficiary] += amount;

        emit Vested(amount, msg.sender);
    }

    /**
     * @return the next time when the tokens may be released.
     */
    function releaseDate() public view returns (uint256) {
        return _nextReleaseDate;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public {
        require(
            block.timestamp >= _nextReleaseDate,
            "release: Current time is before release time"
        );

        uint256 balance = balanceOf(msg.sender);
        require(balance > 0, "release: No tokens vested");

        // Release the monthly amount or the remaining balance, whichever is smaller
        uint256 amountToWithdraw = amountPerMonth;
        if (balance < amountPerMonth) {
            amountToWithdraw = balance;
        }

        // Set the next release date to one month in the future
        _nextReleaseDate = BokkyPooBahsDateTimeLibrary.addMonths(
            _nextReleaseDate,
            1
        );

        _balances[msg.sender] -= amountToWithdraw;
        token().safeTransfer(msg.sender, amountToWithdraw);

        emit Released(amountToWithdraw, msg.sender);
    }

    event Released(uint256 amount, address indexed beneficiary);
    event Vested(uint256 amount, address indexed beneficiary);
}
