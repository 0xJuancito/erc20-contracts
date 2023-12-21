// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICommonBlacklist {

    /**
     * @notice Limits struct
     */
    struct TokenLimit {
        uint256 dailyIncome;
        uint256 monthlyIncome;
        uint256 dailyOutcome;
        uint256 monthlyOutcome;
    }

    /**
     * @notice Limits struct
     */
    struct TokenTransfers {
        uint256 income;
        uint256 outcome;
    }

    /**
     * @notice Limits disabling struct
     */
    struct TokenLimitDisabling {
        bool hasDailyIncomeLimit;
        bool hasMonthlyIncomeLimit;
        bool hasDailyOutcomeLimit;
        bool hasMonthlyOutcomeLimit;
    }

    /**
     * @notice Add user to global blacklist
     * @param _users: users array for adding to blacklist
     *
     * @dev Callable by blacklist operator
     *
     */
    function addUsersToBlacklist(
        address[] memory _users
    ) external;

    /**
     * @notice Remove users from global blacklist
     * @param _users: users array for removing from blacklist
     *
     * @dev Callable by blacklist operator
     *
     */
    function removeUsersFromBlacklist(
        address[] memory _users
    ) external;

    /**
     * @notice Add user to internal blacklist
     * @param _token: address of token contract
     * @param _users: users array for adding to blacklist
     *
     * @dev Callable by blacklist operator
     *
     */
    function addUsersToInternalBlacklist(
        address _token,
        address[] memory _users
    ) external;

    /**
     * @notice Remove users from internal blacklist
     * @param _token: address of token contract
     * @param _users: users array for removing from blacklist
     *
     * @dev Callable by blacklist operator
     *
     */
    function removeUsersFromInternalBlacklist(
        address _token,
        address[] memory _users
    ) external;

    /**
     * @notice Getting information if user blacklisted
     * @param _sender: sender address
     * @param _from: from address
     * @param _to: to address
     *
     */
    function userIsBlacklisted(
        address _sender,
        address _from,
        address _to
    ) external view returns(bool);

    /**
     * @notice Getting information if user in internal blacklist
     * @param _token: address of token contract
     * @param _sender: sender address
     * @param _from: from address
     * @param _to: to address
     *
     */
    function userIsInternalBlacklisted(
        address _token,
        address _sender,
        address _from,
        address _to
    ) external view returns(bool);

    /**
     * @notice Getting information about the presence of users from the list in the blacklist
     * @param _token: address of token contract
     * @param _users: list of user address
     *
     */
    function usersFromListIsBlacklisted(
        address _token,
        address[] memory _users
    ) external view returns(address[] memory);

    /**
     * @notice Function returns current day
     */
    function getCurrentDay() external view returns(uint256);

    /**
     * @notice Function returns current month
     */
    function getCurrentMonth() external view returns(uint256);

    /**
     * @notice Setting token limits
     * @param _token: address of token contract
     * @param _dailyIncomeLimit: day limit for income token transfer
     * @param _monthlyIncomeLimit: month limit for income token transfer
     * @param _dailyOutcomeLimit: day limit for outcome token transfer
     * @param _monthlyOutcomeLimit: month limit for outcome token transfer
     *
     * @dev Callable by blacklist operator
     *
     */
    function setTokenLimits(
        address _token,
        uint256 _dailyIncomeLimit,
        uint256 _monthlyIncomeLimit,
        uint256 _dailyOutcomeLimit,
        uint256 _monthlyOutcomeLimit
    ) external;

    /**
     * @notice Adding Contracts to exclusion list
     * @param _contract: address of contract
     *
     * @dev Callable by blacklist operator
     *
     */
    function addContractToExclusionList(
        address _contract
    ) external;

    /**
     * @notice Removing Contracts from exclusion list
     * @param _contract: address of contract
     *
     * @dev Callable by blacklist operator
     *
     */
    function removeContractFromExclusionList(
        address _contract
    ) external;

    /**
     * @notice Checking the user for the limits allows
     * @param _from: spender user address
     * @param _to: recipient user address
     * @param _amount: amount of tokens
     *
     */
    function limitAllows(
        address _from,
        address _to,
        uint256 _amount
    ) external;

    /**
     * @notice Getting token limits
     * @param _token: address of token contract
     *
     */
    function getTokenLimits(
        address _token
    ) external view returns(TokenLimit memory);

    /**
     * @notice Getting user token transfers
     * @param _token: address of token contract
     * @param _user: user address
     *
     */
    function getUserTokenTransfers(
        address _token,
        address _user
    ) external view returns(
        uint256 dailyIncomeTransfers,
        uint256 monthlyIncomeTransfers,
        uint256 dailyOutcomeTransfers,
        uint256 monthlyOutcomeTransfers
    );

    /**
     * @notice Disable/Enable token limits
     * @param _token: address of token contract
     * @param _hasDailyIncomeLimit: for disabling income day limits
     * @param _hasMonthlyIncomeLimit: for disabling income month limits
     * @param _hasDailyOutcomeLimit: for disabling outcome day limits
     * @param _hasMonthlyOutcomeLimit: for disabling outcome month limits
     *
     * @dev Callable by blacklist operator
     *
     */
    function changeDisablingTokenLimits(
        address _token,
        bool _hasDailyIncomeLimit,
        bool _hasMonthlyIncomeLimit,
        bool _hasDailyOutcomeLimit,
        bool _hasMonthlyOutcomeLimit
    ) external;

    /**
     * @notice Getting remaining limit for user
     * @param _token: address of token contract
     * @param _user: user address
     *
     */
    function getUserRemainingLimit(
        address _token,
        address _user
    ) external view returns(
        uint256 dailyIncomeRemaining,
        uint256 monthlyIncomeRemaining,
        uint256 dailyOutcomeRemaining,
        uint256 monthlyOutcomeRemaining
    );
}
