pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../IFundsDistributionToken.sol";
import "../FundsDistributionToken.sol";

contract FDT_ERC20Extension is IFundsDistributionToken, FundsDistributionToken {
    using SafeCast for uint256;
    using SafeCast for int256;

    // token in which the funds can be sent to the FundsDistributionToken
    IERC20 public fundsToken;

    // balance of fundsToken that the FundsDistributionToken currently holds
    uint256 public fundsTokenBalance;

    constructor(
        string memory name,
        string memory symbol,
        IERC20 _fundsToken
    ) FundsDistributionToken(name, symbol) {
        require(
            address(_fundsToken) != address(0),
            "FDT_ERC20Extension: INVALID_FUNDS_TOKEN_ADDRESS"
        );

        fundsToken = _fundsToken;
    }

    /**
     * @notice Withdraws all available funds for a token holder
     */
    function withdrawFunds() external {
        uint256 withdrawableFunds = _prepareWithdraw();

        SafeERC20.safeTransfer(fundsToken, msg.sender, withdrawableFunds);

        _updateFundsTokenBalance();
    }

    /**
     * @dev Updates the current funds token balance
     * and returns the difference of new and previous funds token balances
     * @return A int256 representing the difference of the new and previous funds token balance
     */
    function _updateFundsTokenBalance() internal returns (int256) {
        uint256 prevFundsTokenBalance = fundsTokenBalance;

        fundsTokenBalance = fundsToken.balanceOf(address(this));

        return fundsTokenBalance.toInt256() - prevFundsTokenBalance.toInt256();
    }

    /**
     * @notice Register a payment of funds in tokens. May be called directly after a deposit is made.
     * @dev Calls _updateFundsTokenBalance(), whereby the contract computes the delta of the previous and the new
     * funds token balance and increments the total received funds (cumulative) by delta by calling _registerFunds()
     */
    function updateFundsReceived() external {
        int256 newFunds = _updateFundsTokenBalance();

        if (newFunds > 0) {
            _distributeFunds(newFunds.toUint256());
        }
    }
}
