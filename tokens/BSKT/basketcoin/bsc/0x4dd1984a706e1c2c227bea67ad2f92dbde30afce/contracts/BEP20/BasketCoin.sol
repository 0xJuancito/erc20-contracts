// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./token/BEP20.sol";
import "./security/Pausable.sol";
import "./access/Ownable.sol";
import "./utils/SignatureChecker.sol";

contract BasketCoinToken is BEP20, Pausable, Ownable {
    address public minterAddress;

    constructor(address _taxAddress) BEP20("BasketCoin", "BSKT", _taxAddress) {}

    modifier onlyAuth() {
        address user = _msgSender();
        require(
            user == owner() || user == minterAddress,
            "Auth people only accessible"
        );
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Triggers normal state.
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - The contract must not be unpaused.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Can only be called by the current auth people.
     * Which means, bridge contract and admin only accessible
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `amount` number token to be generate.
     */
    function mint(address to, uint256 amount) public onlyAuth {
        _mint(to, amount);
    }

    /** @dev Destroys `amount` tokens from `account`, reducing
     * the total supply.
     *
     * Can only be called by the current auth people.
     * Which means, bridge contract and admin only accessible
     *
     * Requirements:
     *
     * - `user` cannot be the zero address.
     * - `amount` number token to be burned
     */
    function burn(address user, uint256 amount) public onlyAuth {
        _burn(user, amount);
    }

    struct burnStore {
        address user;
        uint256 amount;
    }

    /** @dev Destroys `amount` tokens from `mutilple accounts`, reducing
     * the total supply.
     *
     * Can only be called by the current auth people.
     * Which means, bridge contract and admin only accessible
     *
     * Requirements:
     *
     * - `user` cannot be the zero address.
     * - `amount` number token to be burned
     * - `Admin should pass multidimensional array`
     */
    function multiBurn(burnStore[] memory vars) public onlyAuth {
        uint256 length = vars.length;

        for (uint256 i; i < length; i++) {
            _burn(vars[i].user, vars[i].amount);
        }
    }

    /**
     * @dev update the taxFee percentage.
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - `amount` taxFee.
     */
    function taxFeeUpdate(uint256 amount) public onlyOwner {
        _taxFee = amount;
    }

    /**
     * @dev update the burnFee percentage.
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - `account` burnFee.
     */
    function burnFeeUpdate(uint256 amount) public onlyOwner {
        _burnFee = amount;
    }

    /**
     * @dev This function help to stop and unstop the fee deduction while transferred the tokens.
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - `status`
     *    if true - fee will be deduct for all transfer.
     *    if false - fee will not deduct for all transfer.
     */
    function feeStatusUpdate(bool status) public onlyOwner {
        feeDeductStatus = status;
    }

    /**
     * @dev it will be help to remove from fee.
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - `account` user address.
     * - `status`
     *    if true - fee will not deduct for this user.
     *    if false - fee will be deduct for all transfer.
     */
    function excludeFromFee(address account, bool status) public onlyOwner {
        excludeFee[account] = status;
    }

    /**
     * @dev update the bridge contract address
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - `account` bridge contract address.
     */
    function taxFeeAddressUpdate(address account) public onlyOwner {
        _taxFeeAddress = account;
    }

    /**
     * @dev update the bridge contract address
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - `account` bridge contract address.
     */
    function minterAddressUpdate(address account) public onlyOwner {
        minterAddress = account;
    }

    /**
     * @dev This function is help to recover the unnecessary or stucked bnb funds.
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - `user` received address.
     * - `amount` number of tokens.
     */
    function bnbEmergencySafe(address account, uint256 amount)
        public
        onlyOwner
    {
        payable(account).transfer(amount);
    }

    /**
     * @dev This function is help to recover the unnecessary or stucked token funds.
     *
     * Can only be called by the current owner.
     *
     * Requirements:
     *
     * - `token` token contract address.
     * - `user` received address.
     * - `amount` number of tokens.
     */
    function tokenEmergencySafe(
        address token,
        address account,
        uint256 amount
    ) public onlyOwner {
        IBEP20(token).transfer(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Returns the current taxfee.
     */
    function taxFee() public view returns (uint256) {
        return _taxFee;
    }

    /**
     * @dev Returns the current burnfee.
     */
    function burnFee() public view returns (uint256) {
        return _burnFee;
    }

    /**
     * @dev Returns the current state status fee deduction.
     */
    function feeStatus() public view returns (bool) {
        return feeDeductStatus;
    }

    /**
     * @dev Returns the current taxFeeAddress.
     *
     * example - taxfee - 1% will goes to this wallet address.
     */
    function taxFeeAddress() public view returns (address) {
        return _taxFeeAddress;
    }
}
