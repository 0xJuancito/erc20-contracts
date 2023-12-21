// SPDX-License-Identifier: ISC


pragma solidity ^0.8.0;

import "./utils/Ownable.sol";
import "./utils/SafeMath.sol";
import "./IBEP20.sol";
import "./utils/Context.sol";
import "./utils/AdminRole.sol";
import "./utils/Pausable.sol";

/// @title Main contract BEP20 - Coin of the champions
/// @author ISC
/// @notice
/// @dev All function calls are currently implemented without side effects
contract COC is IBEP20, AdminRole, Pausable {
    using SafeMath for uint256;

    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;

    uint256 private _GRANULARITY = 100;
    uint256 _TAX_FEE;
    uint256 private _PREVIOUS_TAX_FEE = _TAX_FEE;
    uint256 _BURN_FEE;
    uint256 private _PREVIOUS_BURN_FEE = _BURN_FEE;

    uint256 private constant _MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;

    uint256 private _tFeeTotal;
    uint256 private _tBurnTotal;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcludedFromReward;
    address[] private _excludedFromReward;

    mapping(address => bool) private _blacklistAddress;

    constructor(string memory name_, string memory symbol_, uint256 decimals_, uint256 taxFee_, uint256 burnFee_){
        _name = name_;
        _symbol = symbol_;
        _decimals = uint8(decimals_);
        _TAX_FEE = taxFee_ * _GRANULARITY;
        _BURN_FEE = burnFee_ * _GRANULARITY;

        _tTotal = 1000000000000000 * (10 ** _decimals);
        _rTotal = (_MAX - (_MAX % _tTotal));

        //exclude owner and this contract from fee
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;

        _rOwned[_msgSender()] = _rTotal;
        emit Transfer(address(0),_msgSender(), _tTotal);
    }

    /**
    * @dev Returns the token name.
    */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {BEP20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    /**
    * @dev Returns the tax fee
    */
    function getTaxFee() public view returns (uint256) {
        return _TAX_FEE / _GRANULARITY;
    }

    /**
    * @dev Returns the burn fee
    */
    function getBurnFee() public view returns (uint256) {
        return _BURN_FEE / _GRANULARITY;
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromReward[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view override returns (address) {
        return owner();
    }

    /**
     * @dev See {BEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {BEP20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {BEP20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev See {BEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override whenNotPaused returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {BEP20-allowance}.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public whenNotPaused returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotPaused returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(!isBlacklisted(sender), "BEP20: sender address is blacklisted");
        require(!isBlacklisted(recipient), "BEP20: recipient address is blacklisted");
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "BEP20: transfer amount must be greater than zero");

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            takeFee = false;
            removeAllFee();
        }

        if (_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee)
            restoreAllFee();

        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
    * @dev Add the address from the list of addresses excluded from rewards
    * Can only be called by the current owner.
    * Requirements:
    *
    * - `account` is not already excluded
    */
    function excludeFromReward(address account) public onlyAdmin() {
        require(!_isExcludedFromReward[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromReward[account] = true;
        _excludedFromReward.push(account);
    }

    /**
    * @dev Removes the address from the list of addresses excluded from rewards
    * Can only be called by the current owner.
    *
    * Requirements:
    *
    * - `account` is excluded
    */
    function includeInReward(address account) external onlyAdmin() {
        require(_isExcludedFromReward[account], "Account is already included");
        for (uint256 i = 0; i < _excludedFromReward.length; i++) {
            if (_excludedFromReward[i] == account) {
                _excludedFromReward[i] = _excludedFromReward[_excludedFromReward.length - 1];
                _tOwned[account] = 0;
                _isExcludedFromReward[account] = false;
                _excludedFromReward.pop();
                break;
            }
        }
    }

    /**
    * @dev Returns if the address is excluded from reward
    */
    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcludedFromReward[account];
    }

    /**
    * @dev Set address of account as excluded from fee
    * Can only be called by the current owner.
    */
    function excludeFromFee(address account) public onlyAdmin() {
        _isExcludedFromFee[account] = true;
    }

    /**
    * @dev Set address of account as included from fee
    * Can only be called by the current owner.
    */
    function includeInFee(address account) public onlyAdmin() {
        _isExcludedFromFee[account] = false;
    }

    /**
    * @dev Returns if the address is excluded from fee
    */
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function removeAllFee() private {
        if(_TAX_FEE == 0 && _BURN_FEE == 0) return;

        _PREVIOUS_TAX_FEE = _TAX_FEE;
        _PREVIOUS_BURN_FEE = _BURN_FEE;

        _TAX_FEE = 0;
        _BURN_FEE = 0;
    }

    function restoreAllFee() private {
        _TAX_FEE = _PREVIOUS_TAX_FEE;
        _BURN_FEE = _PREVIOUS_BURN_FEE;
    }

    function _reflectFee(uint256 rFee_, uint256 rBurn_, uint256 tFee_, uint256 tBurn_) private {
        _rTotal = _rTotal.sub(rFee_).sub(rBurn_);
        _tTotal = _tTotal.sub(tBurn_);
        _tFeeTotal = _tFeeTotal.add(tFee_).add(tBurn_);
        _tBurnTotal = _tBurnTotal.add(tBurn_);
        emit Transfer(address(this), address(0), tBurn_);
    }

    /**
    * @dev Returns fee total value
    */
    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    /**
    * @dev Returns burn total value
    */
    function totalBurn() public view returns (uint256) {
        return _tBurnTotal;
    }

    function _transferStandard(address sender_, address recipient_, uint256 tAmount_) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn, , uint256 tFee, uint256 tBurn) = _getTransferValues(tAmount_);

        _rOwned[sender_] = _rOwned[sender_].sub(rAmount);
        _rOwned[recipient_] = _rOwned[recipient_].add(rTransferAmount);

        _reflectFee(rFee, rBurn, tFee, tBurn);
    }

    function _transferFromExcluded(address sender_, address recipient_, uint256 tAmount_) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn, , uint256 tFee, uint256 tBurn) = _getTransferValues(tAmount_);
        _tOwned[sender_] = _tOwned[sender_].sub(tAmount_);
        _rOwned[sender_] = _rOwned[sender_].sub(rAmount);
        _rOwned[recipient_] = _rOwned[recipient_].add(rTransferAmount);
        _reflectFee(rFee, rBurn, tFee, tBurn);
    }

    function _transferToExcluded(address sender_, address recipient_, uint256 tAmount_) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getTransferValues(tAmount_);
        _rOwned[sender_] = _rOwned[sender_].sub(rAmount);
        _tOwned[recipient_] = _tOwned[recipient_].add(tTransferAmount);
        _rOwned[recipient_] = _rOwned[recipient_].add(rTransferAmount);
        _reflectFee(rFee, rBurn, tFee, tBurn);
    }

    function _transferBothExcluded(address sender_, address recipient_, uint256 tAmount_) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getTransferValues(tAmount_);
        _tOwned[sender_] = _tOwned[sender_].sub(tAmount_);
        _rOwned[sender_] = _rOwned[sender_].sub(rAmount);
        _tOwned[recipient_] = _tOwned[recipient_].add(tTransferAmount);
        _rOwned[recipient_] = _rOwned[recipient_].add(rTransferAmount);
        _reflectFee(rFee, rBurn, tFee, tBurn);
    }

    function _getTransferValues(uint256 tAmount_) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tFee, uint256 tBurn) = _getFee(tAmount_);
        uint256 tTransferAmount = tAmount_.sub(tFee).sub(tBurn);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn) = _getRValues(tAmount_, tFee , tBurn, _getRate());
        return (rAmount, rTransferAmount, rFee, rBurn, tTransferAmount, tFee, tBurn);
    }

    function _getFee(uint256 tAmount_) private view returns (uint256, uint256) {
        uint256 tFee = ((tAmount_.mul(_TAX_FEE)).div(_GRANULARITY)).div(100);
        uint256 tBurn = ((tAmount_.mul(_BURN_FEE)).div(_GRANULARITY)).div(100);
        return (tFee, tBurn);
    }

    function _getRValues(uint256 tAmount_, uint256 tFee_, uint256 tBurn_, uint256 currentRate_) private pure returns (uint256, uint256, uint256, uint256) {
        uint256 rAmount = tAmount_.mul(currentRate_);
        uint256 rFee = tFee_.mul(currentRate_);
        uint256 rBurn = tBurn_.mul(currentRate_);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rBurn);
        return (rAmount, rTransferAmount, rFee, rBurn);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excludedFromReward.length; i++) {
            if (_rOwned[_excludedFromReward[i]] > rSupply || _tOwned[_excludedFromReward[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excludedFromReward[i]]);
            tSupply = tSupply.sub(_tOwned[_excludedFromReward[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /**
    * @dev Return value of token from value token reflection
    *
    * Requirements:
    *
    * - `rAmount` must be less than total reflection
    */
    function tokenFromReflection(uint256 rAmount_) public view returns(uint256) {
        require(rAmount_ <= _rTotal, "BEP20: amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount_.div(currentRate);
    }

    /**
    * @dev Return value of reflection from token amount
    *
    * Requirements:
    *
        * - `tAmount` must be less than total supply
    */
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,,) = _getTransferValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,,) = _getTransferValues(tAmount);
            return rTransferAmount;
        }
    }

    /**
    * @dev Set new tax fee for every transaction
    * Can only be called by the current owner.
    */
    function setTaxFeePercent(uint256 taxFee_) external onlyAdmin() {
        _TAX_FEE = taxFee_;
    }

    /**
    * @dev Set new burn fee for every transaction
    * Can only be called by the current owner.
    */
    function setBurnFeePercent(uint256 burnFee_) external onlyAdmin() {
        _BURN_FEE = burnFee_;
    }

    /**
    * @dev Add address to blacklist
    * Can only be called by the current owner.
    */
    function addAddressToBlacklist(address addressToAdd_) external onlyAdmin() {
        _blacklistAddress[addressToAdd_] = true;
    }

    /**
    * @dev Remove address to blacklist
    * Can only be called by the current owner.
    */
    function removeAddressFromBlacklist(address addressToRemove_) external onlyAdmin() {
        _blacklistAddress[addressToRemove_] = false;
    }

    /**
    * @dev Return `true` if address is blacklisted
    */
    function isBlacklisted(address addressToCheck_) public view returns(bool) {
        return _blacklistAddress[addressToCheck_];
    }

}
