// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISPEC is IERC20 {
    /**
     * @notice Emitted when a new set of fee receivers are set
     */
    event FeeReceiversSet();

    /**
     * @notice Emitted when a new Uniswap pool address is set
     * @param _pool New Uniswap pool address
     */
    event PoolAddressSet(address _pool);

    /**
     * @notice Emitted when trading fee of the token is changed
     * @param _tradingFee New trading fee in percentage * 100
     */
    event TradingFeeSet(uint256 _tradingFee);

    /**
     * @notice Emitted when a stable address is added to the list
     * @param _stableAddress Address that was added to the list
     */
    event StableBalanceAddressAdded(address _stableAddress);

    /**
     * @notice Emitted when a stable address is removed from the list
     * @param _stableAddress Address that was removed from the list
     */
    event StableBalanceAddressRemoved(address _stableAddress);

    /**
     * @notice Emitted when a rebase happens
     * @param _supplyDelta The amount of supply that was added to the total supply
     */
    event Rebase(uint256 _supplyDelta);

    /**
     * @dev Indicates that now is too soon to call the rebase
     */
    error RebaseNotAvailableNow();

    /**
     * @dev Indicates that an address is 0x00
     */
    error InvalidAddress();

    /**
     * @dev Indicates an error when an stable address is the pool address
     * @param _stableAddress Address that was going to be added to the list
     */
    error StableAddressCannotBePoolAddress(address _stableAddress);

    /**
     * @dev Indicates an error when an stable address is already exists in the list
     * @param _stableAddress Address that was going to be added to the list
     */
    error StableAddressAlreadyExists(address _stableAddress);

    /**
     * @dev Indicates an error when an stable address is given to be removed but it is not found
     * @param _stableAddress Address that was going to be removed from the list
     */
    error StableAddressNotFound(address _stableAddress);

    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);

    /**
     * @notice Calculates share amount to balance amount and returns it
     * @param _sharesAmount Amount of shares to convert
     * @return _balanceAmount Returns the balance amount relative to the share amount
     */
    function convertSharesToBalance(
        uint256 _sharesAmount
    ) external view returns (uint256 _balanceAmount);

    /**
     * @notice Calculates balance amount to share amount and returns it
     * @param _balanceAmount Amount of balance to convert
     * @return _sharesAmount Returns the share amount relative to the balance amount
     */
    function convertBalanceToShares(
        uint256 _balanceAmount
    ) external view returns (uint256 _sharesAmount);

    /**
     * @notice Returns the amount of shares per 1 balance amount
     * @return Returns the amount of shares per 1 balance amount
     */
    function sharePerBalance() external view returns (uint256);

    /**
     * @notice Rebases and adds reward to the totalSupply
     */
    function rebase() external returns (uint256);

    /**
     * @notice Returns true if the address is either the owner, stableAddress or feeReceiver
     * @param _holder The address to check
     * @return taxFree Returns whether if the holder is tax free or not
     */
    function isTaxFree(address _holder) external view returns (bool taxFree);

    /**
     * @notice Removes an stable address from the list of stable addresses
     * @param _stableAddress The address to remove from the list
     */
    function removeStableAddress(address _stableAddress) external;

    /**
     * @notice Adds an address to the stable addresses
     * @param _stableAddress The new address to add
     */
    function addStableAddress(address _stableAddress) external;

    /**
     * @notice Sets the address of the Uniswap V2 pool
     * @param _pool Address of the Uniswap V2 pool
     */
    function setPoolAddress(address _pool) external;

    /**
     * @notice Sets the addresses of fee receivers
     * @param _feeReceivers Addresses of the 3 fee receivers
     */
    function setFeeReceivers(address[3] calldata _feeReceivers) external;

    /**
     * @notice Sets the trading fee percentage
     * @param _newTradingFee The new trading fee percentage
     */
    function setTradingFee(uint256 _newTradingFee) external;
}
