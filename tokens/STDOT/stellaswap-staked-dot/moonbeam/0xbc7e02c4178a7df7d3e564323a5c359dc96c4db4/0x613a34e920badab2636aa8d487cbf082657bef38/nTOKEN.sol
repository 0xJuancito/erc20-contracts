// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "IERC20.sol";
import "Pausable.sol";

abstract contract nTOKEN is IERC20, Pausable {

    /**
     * @dev User balances
    */
    mapping (address => uint256) private _balances;

    /**
     * @dev Allowances are nominated in tokens
     */
    mapping (address => mapping (address => uint256)) private _allowances;

    /**
     * @dev Storage position used for holding the total amount of tokens in existence.
     */
    uint256 internal _totalSupply;

    /**
     * @return the amount of tokens in existence.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @return the entire amount of TOKENs controlled by the protocol.
     *
     * @dev The sum of all TOKEN balances in the protocol.
     */
    function getTotalPooledToken() public view returns (uint256) {
        return _getTotalPooledToken();
    }

    /**
     * @return the amount of tokens owned by the `_account`.
     */
    function balanceOf(address _account) public view override returns (uint256) {
        return _balances[_account];
    }

    /**
     * @notice Moves `_amount` tokens from the caller's account to the `_recipient` account.
     *
     * @return a boolean value indicating whether the operation succeeded.
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the caller must have a balance of at least `_amount`.
     * - the contract must not be paused.
     * @dev The `_amount` argument is the amount of tokens.
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    /**
     * @return the remaining number of tokens that `_spender` is allowed to spend
     * on behalf of `_owner` through `transferFrom`. This is zero by default.
     *
     * @dev This value changes when `approve` or `transferFrom` is called.
     */
    function allowance(address _owner, address _spender) public view override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
     *
     * @return a boolean value indicating whether the operation succeeded.
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `_spender` cannot be the zero address.
     * - the contract must not be paused.
     *
     * @dev The `_amount` argument is the amount of tokens.
     */
    function approve(address _spender, uint256 _amount) public override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient` using the
     * allowance mechanism. `_amount` is then deducted from the caller's
     * allowance.
     *
     * @return a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_sender` and `_recipient` cannot be the zero addresses.
     * - `_sender` must have a balance of at least `_amount`.
     * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
     * - the contract must not be paused.
     *
     * @dev The `_amount` argument is the amount of tokens.
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");

        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, currentAllowance - _amount);
        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol#L42
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_spender` cannot be the the zero address.
     * - the contract must not be paused.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + _addedValue);
        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `_spender` by the caller by `_subtractedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol#L42
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_spender` cannot be the zero address.
     * - `_spender` must have allowance for the caller of at least `_subtractedValue`.
     * - the contract must not be paused.
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "DECREASED_ALLOWANCE_BELOW_ZERO");
        _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
        return true;
    }

    /**
     * @return the amount of shares that corresponds to the protocol-controlled TOKEN `amount`.
     */
    function getSharesByPooledToken(uint256 _amount) public view returns (uint256) {
        uint256 totalPooledToken = _getTotalPooledToken();
        if (totalPooledToken == 0) {
            return 0;
        } else {
            return _amount * _totalSupply / totalPooledToken;
        }
    }

    /**
     * @return the amount of TOKEN that corresponds to `_sharesAmount` of token.
     */
    function getPooledTokenByShares(uint256 _sharesAmount) public view returns (uint256) {
        uint256 _totalShares = _totalSupply;
        if (_totalShares == 0) {
            return 0;
        } else {
            return _sharesAmount * _getTotalPooledToken() / _totalShares;
        }
    }

    /**
     * @return the total amount (in wei) of TOKEN controlled by the protocol.
     * @dev This is used for calaulating tokens from shares and vice versa.
     * @dev This function is required to be implemented in a derived contract.
     */
    function _getTotalPooledToken() internal view virtual returns (uint256);

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
     * Requirements:
     *
     * - `_sender` cannot be the zero address.
     * - `_recipient` cannot be the zero address.
     * - `_sender` must hold at least `_amount` of tokens.
     * - the contract must not be paused.
     *
     * Emits a `Transfer` event.
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal whenNotPaused {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");

        uint256 currentSenderBalance = _balances[_sender];
        require(_amount <= currentSenderBalance, "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        _balances[_sender] = currentSenderBalance - _amount;
        _balances[_recipient] = _balances[_recipient] + _amount;

        emit Transfer(_sender, _recipient, _amount);
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `_owner` cannot be the zero address.
     * - `_spender` cannot be the zero address.
     * - the contract must not be paused.
     */
    function _approve(address _owner, address _spender, uint256 _amount) internal whenNotPaused {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
     * @notice Creates `_amount` of tokens and assigns them to `_recipient`, increasing the total amount of tokens.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the contract must not be paused.
     */
    function _mintShares(
        address _recipient,
        uint256 _amount
    )
        internal
        whenNotPaused
        returns (uint256 newTotalSupply)
    {
        require(_recipient != address(0), "MINT_TO_THE_ZERO_ADDRESS");

        newTotalSupply = _totalSupply + _amount;
        _totalSupply = newTotalSupply;

        _balances[_recipient] = _balances[_recipient] + _amount;

        emit Transfer(address(0), _recipient, _amount);
    }

    /**
     * @notice Destroys `_amount` of tokens from `_account`'s holdings, decreasing the total amount of tokens.
     *
     * Requirements:
     *
     * - `_account` cannot be the zero address.
     * - `_account` must hold at least `_amount` of tokens.
     * - the contract must not be paused.
     */
    function _burnShares(
        address _account,
        uint256 _amount
    )
        internal
        whenNotPaused
        returns (uint256 newTotalSupply)
    {
        require(_account != address(0), "BURN_FROM_THE_ZERO_ADDRESS");

        uint256 accountBalance = _balances[_account];
        require(_amount <= accountBalance, "BURN_AMOUNT_EXCEEDS_BALANCE");

        newTotalSupply = _totalSupply - _amount;
        _totalSupply = newTotalSupply;

        _balances[_account] = accountBalance - _amount;

        emit Transfer(_account, address(0), _amount);
    }
}
