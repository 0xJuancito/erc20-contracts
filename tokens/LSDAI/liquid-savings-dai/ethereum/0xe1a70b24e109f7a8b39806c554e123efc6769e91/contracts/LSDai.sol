// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
// Custom Ownable logic from OZ
import {Ownable} from "./Ownable.sol";

// Interfaces
import {ILSDai} from "./interfaces/ILSDai.sol";

// DSR helpers
import {RMath} from "./libraries/RMath.sol";
import {IDai} from "./interfaces/IDai.sol";
import {IPot} from "./interfaces/IPot.sol";
import {IJoin} from "./interfaces/IJoin.sol";
import {IVat} from "./interfaces/IVat.sol";

/**
 * @title LSDAI
 * @dev LSDai is a rebasing token that earns interest on DAI deposited in the MakerDAO DSR.
 */
contract LSDai is Ownable, ILSDai {
  error LSDai__AlreadyInitialized();
  error LSDai__DepositCap();
  error LSDai__WithdrawalFeeHigh();
  error LSDai__InterestFeeHigh();
  error LSDai__TransferToZeroAddress();
  error LSDai__TransferFromZeroAddress();
  error LSDai__TransferToLSDaiContract();
  error LSDai__MintToZeroAddress();
  error LSDai__BurnFromZeroAddress();
  error LSDai__SharesAmountExceedsBalance();
  error LSDai__AmountExceedsBalance();
  error LSDai__FeeRecipientZeroAddress();
  error LSDai__RebaseOverflow(uint256 preRebaseTotalPooledDai, uint256 postRebaseTotalPooledDai);

  using SafeMath for uint256;
  ///////////////////////////
  //     ERC20 storage     //
  ///////////////////////////

  /**
   * @dev Returns the name of the token.
   */
  string public name;

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the
   * name.
   */
  string public symbol;

  /**
   * @dev Returns the number of decimals used to get its user representation.
   */
  uint256 public immutable decimals = 18;

  /**
   * @dev Returns the amount of tokens in existence.
   */
  mapping(address => mapping(address => uint256)) private _allowances;

  /*//////////////////////////////////////////////////////////////
                                 LSDAI STORAGE
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev LSDAI is initialized.
   */
  bool private _initialized;

  /**
   * @dev LSDAI deposit cap. This is the maximum amount of DAI that can be deposited.
   */
  uint256 public depositCap;

  /**
   * @dev Address shares
   */
  mapping(address => uint256) private _shares;

  /**
   * @dev Total shares of LSDAI
   */
  uint256 private _totalLsdaiShares;

  /**
   * @notice Total amount of DAI controlled by LSDAI at MakerDAO DSR.
   * @dev This value must be updated before depositing or withdrawing.
   */
  uint256 private _totalPooledDai;

  /**
   * @dev the total amount of pot shares
   */
  uint256 private _totalPotShares;

  ///////////////////////////
  // LSDAI Fee Information //
  ///////////////////////////
  /**
   * @notice Interest fee taken on interest earned, in basis points.
   */
  uint256 public interestFee;

  /**
   * @notice Withdrawal fee taken on exit, in basis points.
   */
  uint256 public withdrawalFee;

  /**
   * @notice Fee recipient address.
   */
  address public feeRecipient;

  ///////////////////////////
  // MakerDAO DSR Contracts //
  ///////////////////////////
  IVat public immutable vat = IVat(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
  IPot public immutable pot = IPot(0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7);
  IJoin public immutable daiJoin = IJoin(0x9759A6Ac90977b93B58547b4A71c78317f391A28);
  IDai public immutable dai = IDai(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  /**
   * @dev initializes the contract.
   * @param _depositCap the DAI deposit cap.
   * @param _interestFee the interest fee percentage in basis points (1/100 of a percent)
   * @param _withdrawalFee the withdrawal fee percentage in basis points (1/100 of a percent)
   * @param _feeRecipient the address of the fee recipient
   */
  function initialize(uint256 _depositCap, uint256 _interestFee, uint256 _withdrawalFee, address _feeRecipient)
    external
    returns (bool)
  {
    if (_initialized) {
      revert LSDai__AlreadyInitialized();
    }

    // Transfer ownership to message sender
    _transferOwnership(msg.sender);

    // Set ERC20 name and symbol
    name = "Liquid Savings DAI";
    symbol = "LSDAI";

    // Set initial deposit cap to 10m DAI
    setDepositCap(_depositCap);
    // Set fee information
    setFeeRecipient(_feeRecipient);
    setWithdrawalFee(_withdrawalFee);
    setInterestFee(_interestFee);

    _initialized = true;

    // Setup the LSDAI contract to be able to interact with the MakerDAO contracts and DAI token
    vat.hope(address(daiJoin));
    vat.hope(address(pot));
    dai.approve(address(daiJoin), type(uint256).max);

    return true;
  }

  /**
   * @return the amount of shares owned by `_account`.
   */
  function sharesOf(address account) public view returns (uint256) {
    return _shares[account];
  }

  /**
   * @dev returns the amount of pot shares the LSDAI contract has in the DSR pot contract
   */
  function potShares() external view returns (uint256) {
    return pot.pie(address(this));
  }

  /**
   * @dev Deposit DAI and mint LSDAI.
   * @param to The address to mint LSDAI to.
   * @param daiAmount The amount of DAI to deposit.
   * @return amount of LSDAI minted.
   */
  function deposit(address to, uint256 daiAmount) external returns (uint256) {
    dai.transferFrom(msg.sender, address(this), daiAmount);
    return _deposit(to, daiAmount);
  }

  /**
   * @dev Deposit DAI and mint LSDAI.
   * @param to The address to mint LSDAI to.
   * @param daiAmount The amount of DAI to deposit.
   * @param permitNonce The nonce of the permit signature.
   * @param permitExpiry The deadline timestamp, type(uint256).max for no deadline.
   * @param permitV The recovery byte of the signature.
   * @param permitR Half of the ECDSA signature pair.
   * @param permitS Half of the ECDSA signature pair.
   * @return amount of LSDAI minted.
   */
  function depositWithPermit(
    address to,
    uint256 daiAmount,
    uint256 permitNonce,
    uint256 permitExpiry,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external returns (uint256) {
    dai.permit(msg.sender, address(this), permitNonce, permitExpiry, true, permitV, permitR, permitS);
    dai.transferFrom(msg.sender, address(this), daiAmount);
    return _deposit(to, daiAmount);
  }

  /**
   * Withdraw DAI from the contract
   * @param daiAmount The amount of LSDAI to withdraw. wad is denominated in dai
   */
  function withdraw(uint256 daiAmount) external returns (bool) {
    return _withdraw(msg.sender, msg.sender, daiAmount, withdrawalFee);
  }

  /**
   * Withdraw DAI from the contract to a specified address instead of the sender
   * @param to The address to withdraw LSDAI to.
   * @param daiAmount The amount of LSDAI to withdraw. wad is denominated in dai
   */
  function withdrawTo(address to, uint256 daiAmount) external returns (bool) {
    return _withdraw(msg.sender, to, daiAmount, withdrawalFee);
  }

  /**
   * @dev withdraws the pending protocol fees from the DSR pot to the `feeRecipient`. Only callable by the owner.
   */
  function collectFees() external onlyOwner returns (bool) {
    return _withdraw(feeRecipient, feeRecipient, balanceOf(feeRecipient), 0);
  }

  /**
   * @dev Updates the withdrawal fee, possible values between 0 and 0.2%. Only callable by the owner.
   * @param fee The new withdrawal fee, in basis points.
   */
  function setWithdrawalFee(uint256 fee) public onlyOwner {
    if (fee > 20) {
      revert LSDai__WithdrawalFeeHigh();
    }

    withdrawalFee = fee;

    emit WithdrawalFeeSet(fee);
  }

  /**
   * @dev Updates the interest fee. Only callable by the owner.
   * @param fee The new interest fee, in basis points.
   */
  function setInterestFee(uint256 fee) public onlyOwner {
    // Cap at 5% (500 basis points)
    if (fee > 500) {
      revert LSDai__InterestFeeHigh();
    }

    interestFee = fee;

    emit InterestFeeSet(fee);
  }

  /**
   * @dev Updates the fee recipient. Only callable by the owner.
   * @param recipient The new fee recipient.
   */
  function setFeeRecipient(address recipient) public onlyOwner {
    if (recipient == address(0)) {
      revert LSDai__FeeRecipientZeroAddress();
    }

    feeRecipient = recipient;

    emit FeeRecipientSet(recipient);
  }

  /**
   * @return the amount of tokens owned by the `account`.
   *
   * @dev Balances are dynamic and equal the `account`'s share in the amount of the
   * total DAI controlled by the protocol. See `sharesOf`.
   */
  function balanceOf(address account) public view virtual override returns (uint256) {
    return getPooledDaiByShares(sharesOf(account));
  }

  /**
   * @return the amount of shares that corresponds to `daiAmount` protocol-controlled DAI.
   * @param daiAmount The amount of protocol-controlled DAI.
   */
  function getSharesByPooledDai(uint256 daiAmount) public view returns (uint256) {
    // Prevent division by zero
    if (_totalPooledDai == 0) {
      return daiAmount;
    }

    return daiAmount.mul(_totalLsdaiShares).div(_totalPooledDai);
  }

  /**
   * @return the amount of DAI that corresponds to `sharesAmount` token shares.
   * @param sharesAmount The amount of LSDAI shares.
   */
  function getPooledDaiByShares(uint256 sharesAmount) public view returns (uint256) {
    return sharesAmount.mul(_totalPooledDai).div(_totalLsdaiShares);
  }

  /**
   * @return the amount of tokens in existence.
   *
   * @dev Always equals to `_getTotalPooledDai()` since token amount
   * is pegged to the total amount of DAI controlled by the protocol.
   */
  function totalSupply() public view override returns (uint256) {
    return _getTotalPooledDai();
  }

  /**
   * @return the amount of total LSDAI shares
   */
  function totalShares() public view returns (uint256) {
    return _totalLsdaiShares;
  }

  /**
   * @dev rebase the total pooled DAI, user balance and total supply of LSDAI.
   * Can only be called by anyone
   */
  function rebase() external {
    uint256 chi = _getMostRecentChi();
    _rebase(chi, true);
  }

  /**
   * @notice Sets deposit cap. Exclusive for the owner.
   */
  function setDepositCap(uint256 cap) public onlyOwner {
    depositCap = cap;

    emit DepositCapSet(cap);
  }

  /**
   * Returns DAI balance at the MakerDAO DSR contract.
   */
  function getTotalPotSharesValue() external view returns (uint256) {
    uint256 chi = (block.timestamp > pot.rho())
      ? (RMath.rpow(pot.dsr(), block.timestamp - pot.rho()) * pot.chi()) / RMath.RAY
      : pot.chi();

    // total pooled DAI is the total shares times the chi
    return (_totalPotShares * chi) / RMath.RAY;
  }

  ///////////////////////////////////////
  ///////// Internal functions /////////
  /////////////////////////////////////

  /**
   * @dev Deposit DAI and mint LSDAI.
   * @param _to The address to mint LSDAI to.
   * @param _daiAmount The amount of DAI to deposit.
   * @return shares amount of LSDAI minted.
   */
  function _deposit(address _to, uint256 _daiAmount) internal returns (uint256 shares) {
    // Check if the deposit cap is reached
    if (depositCap > 0 && _getTotalPooledDai().add(_daiAmount) > depositCap) {
      revert LSDai__DepositCap();
    }

    uint256 chi = _getMostRecentChi();

    // Calculate the amount of pot shares to mint
    uint256 potSharesAmount = RMath.rdiv(_daiAmount, chi);

    // Mint the shares to the user
    shares = getSharesByPooledDai(_daiAmount);
    _mintShares(_to, shares);

    // Increase the total amount of DAI pooled
    _totalPooledDai = _totalPooledDai.add(_daiAmount);
    // Keep track of total pot shares controlled by LSDAI
    _totalPotShares = _totalPotShares.add(potSharesAmount);

    // Mint LSDAI at 1:1 ratio to DAI
    emit Transfer(address(0), _to, _daiAmount);

    // Join the DSR on behalf of the user
    daiJoin.join(address(this), _daiAmount);
    pot.join(potSharesAmount);
  }

  /**
   * Withdraw shares back to DAI
   * @param _from The address to withdraw LSDAI from.
   * @param _to The address to withdraw DAI to.
   * @param _daiAmount The amount of LSDAI to withdraw. wad is denominated in (1/chi) * dai
   * @param _withdrawFee The fee to be charged on the withdrawal, in basis points.
   */
  function _withdraw(address _from, address _to, uint256 _daiAmount, uint256 _withdrawFee) internal returns (bool) {
    uint256 currentDaiBalance = balanceOf(_from);
    // Check if the user has enough LSDAI
    if (_daiAmount > currentDaiBalance) {
      revert LSDai__AmountExceedsBalance();
    }
    uint256 chi = _getMostRecentChi();

    // Split the amount into the fee and the actual withdrawal
    uint256 feeAmount = _daiAmount.mul(_withdrawFee).div(10_000);
    // Amount going to the user
    uint256 withdrawAmount = _daiAmount.sub(feeAmount);

    // Transfer the fee shares to fee recipient
    // and burn the withdraw shares from the user
    uint256 feeShares = getSharesByPooledDai(feeAmount);
    uint256 withdrawShares = getSharesByPooledDai(withdrawAmount);

    // Decrease the total amount of DAI pooled
    _totalPooledDai = _totalPooledDai.sub(withdrawAmount);

    _transferShares(_from, feeRecipient, feeShares);
    _burnShares(_from, withdrawShares);

    // Withdraw from the DSR, roudning up ensures we get at least the amount of DAI requested
    uint256 withdrawPotShares = RMath.rdivup(withdrawAmount, chi);
    // Reduce the total pot shares controlled by LSDAI
    _totalPotShares = _totalPotShares.sub(withdrawPotShares);

    // Burn LSDAI at 1:1 ratio to DAI
    emit Transfer(_from, address(0), withdrawAmount);

    // Get back the DAI from the DSR to the contract
    pot.exit(withdrawPotShares);

    daiJoin.exit(address(this), withdrawAmount); // wad is in dai units

    // Send it over
    return dai.transfer(_to, withdrawAmount);
  }

  /**
   * @notice Destroys `_sharesAmount` shares from `_account`'s holdings, decreasing the total amount of shares.
   * @dev This doesn't decrease the token total supply.
   *
   * Requirements:
   *
   * - `_account` cannot be the zero address.
   * - `_account` must hold at least `_sharesAmount` shares.
   * - the contract must not be paused.
   */
  function _burnShares(address _account, uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
    if (_account == address(0)) {
      revert LSDai__BurnFromZeroAddress();
    }

    uint256 accountShares = _shares[_account];

    if (_sharesAmount > accountShares) {
      revert LSDai__SharesAmountExceedsBalance();
    }

    uint256 preRebaseTokenAmount = getPooledDaiByShares(_sharesAmount);

    newTotalShares = _totalLsdaiShares.sub(_sharesAmount);

    _totalLsdaiShares = newTotalShares;

    _shares[_account] = accountShares.sub(_sharesAmount);

    uint256 postRebaseTokenAmount = getPooledDaiByShares(_sharesAmount);

    emit SharesBurnt(_account, preRebaseTokenAmount, postRebaseTokenAmount, _sharesAmount);

    // Notice: we're not emitting a Transfer event to the zero address here since shares burn
    // works by redistributing the amount of tokens corresponding to the burned shares between
    // all other token holders. The total supply of the token doesn't change as the result.
    // This is equivalent to performing a send from `address` to each other token holder address,
    // but we cannot reflect this as it would require sending an unbounded number of events.

    // We're emitting `SharesBurnt` event to provide an explicit rebase log record nonetheless.
  }

  /**
   * @dev See {IERC20-allowance}.
   */
  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
   * @dev See {IERC20-approve}.
   *
   * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
   * `transferFrom`. This is semantically equivalent to an infinite approval.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    address owner = msg.sender;
    _approve(owner, spender, amount);
    return true;
  }

  /**
   * @notice Moves `_amount` tokens from the caller's account to the `_recipient` account.
   *
   * @return a boolean value indicating whether the operation succeeded.
   * Emits a `Transfer` event.
   * Emits a `TransferShares` event.
   *
   * Requirements:
   *
   * - `_recipient` cannot be the zero address.
   * - the caller must have a balance of at least `_amount`.
   * - the contract must not be paused.
   *
   * @dev The `_amount` argument is the amount of tokens, not shares.
   */
  function transfer(address _recipient, uint256 _amount) public override returns (bool) {
    _transfer(msg.sender, _recipient, _amount);
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
   * Emits a `TransferShares` event.
   * Emits an `Approval` event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `_sender` and `_recipient` cannot be the zero addresses.
   * - `_sender` must have a balance of at least `_amount`.
   * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
   * - the contract must not be paused.
   *
   * @dev The `_amount` argument is the amount of tokens, not shares.
   */
  function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
    _spendAllowance(_sender, msg.sender, _amount);
    _transfer(_sender, _recipient, _amount);
    return true;
  }

  /**
   * @notice Moves `_sharesAmount` token shares from the caller's account to the `_recipient` account.
   *
   * @return amount of transferred tokens.
   * Emits a `TransferShares` event.
   * Emits a `Transfer` event.
   *
   * Requirements:
   *
   * - `_recipient` cannot be the zero address.
   * - the caller must have at least `_sharesAmount` shares.
   * - the contract must not be paused.
   *
   * @dev The `_sharesAmount` argument is the amount of shares, not tokens.
   */
  function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256) {
    _transferShares(msg.sender, _recipient, _sharesAmount);
    uint256 tokensAmount = getPooledDaiByShares(_sharesAmount);
    _emitTransferEvents(msg.sender, _recipient, tokensAmount, _sharesAmount);
    return tokensAmount;
  }

  /**
   * @dev Atomically increases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {IERC20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    address owner = msg.sender;
    _approve(owner, spender, allowance(owner, spender) + addedValue);
    return true;
  }

  /**
   * @dev Atomically decreases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {IERC20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   * - `spender` must have allowance for the caller of at least
   * `subtractedValue`.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    address owner = msg.sender;
    uint256 currentAllowance = allowance(owner, spender);
    require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
      _approve(owner, spender, currentAllowance - subtractedValue);
    }

    return true;
  }

  /**
   * @notice Moves `_sharesAmount` token shares from the `_sender` account to the `_recipient` account.
   *
   * @return amount of transferred tokens.
   * Emits a `TransferShares` event.
   * Emits a `Transfer` event.
   *
   * Requirements:
   *
   * - `_sender` and `_recipient` cannot be the zero addresses.
   * - `_sender` must have at least `_sharesAmount` shares.
   * - the caller must have allowance for `_sender`'s tokens of at least `getPooledDaiByShares(_sharesAmount)`.
   * - the contract must not be paused.
   *
   * @dev The `_sharesAmount` argument is the amount of shares, not tokens.
   */
  function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount) external returns (uint256) {
    uint256 tokensAmount = getPooledDaiByShares(_sharesAmount);
    _spendAllowance(_sender, msg.sender, tokensAmount);
    _transferShares(_sender, _recipient, _sharesAmount);
    _emitTransferEvents(_sender, _recipient, tokensAmount, _sharesAmount);
    return tokensAmount;
  }

  /**
   * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
   * Emits a `Transfer` event.
   * Emits a `TransferShares` event.
   */
  function _transfer(address _sender, address _recipient, uint256 _amount) internal {
    uint256 _sharesToTransfer = getSharesByPooledDai(_amount);
    _transferShares(_sender, _recipient, _sharesToTransfer);
    _emitTransferEvents(_sender, _recipient, _amount, _sharesToTransfer);
  }

  /**
   * @notice Moves `_sharesAmount` shares from `_sender` to `_recipient`.
   *
   * Requirements:
   *
   * - `_sender` cannot be the zero address.
   * - `_recipient` cannot be the zero address or the `LSDai` token contract itself
   * - `_sender` must hold at least `_sharesAmount` shares.
   * - the contract must not be paused.
   */
  function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
    if (_sender == address(0)) {
      revert LSDai__TransferFromZeroAddress();
    }
    if (_recipient == address(0)) {
      revert LSDai__TransferToZeroAddress();
    }

    if (_recipient == address(this)) {
      revert LSDai__TransferToLSDaiContract();
    }

    // _whenNotStopped();

    uint256 currentSenderShares = _shares[_sender];

    if (_sharesAmount > currentSenderShares) {
      revert LSDai__SharesAmountExceedsBalance();
    }

    _shares[_sender] = currentSenderShares.sub(_sharesAmount);
    _shares[_recipient] = _shares[_recipient].add(_sharesAmount);
  }

  /**
   * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
   *
   * This internal function is equivalent to `approve`, and can be used to
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
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  /**
   * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
   *
   * Does not update the allowance amount in case of infinite allowance.
   * Revert if not enough allowance is available.
   *
   * Might emit an {Approval} event.
   */
  function _spendAllowance(address owner, address spender, uint256 amount) internal {
    uint256 currentAllowance = allowance(owner, spender);
    if (currentAllowance != type(uint256).max) {
      require(currentAllowance >= amount, "ERC20: insufficient allowance");
      unchecked {
        _approve(owner, spender, currentAllowance - amount);
      }
    }
  }

  /**
   * @dev Emits {Transfer} and {TransferShares} events
   */
  function _emitTransferEvents(address _from, address _to, uint256 _tokenAmount, uint256 _sharesAmount) internal {
    emit Transfer(_from, _to, _tokenAmount);
    emit TransferShares(_from, _to, _sharesAmount);
  }

  /**
   * @notice Creates `_sharesAmount` shares and assigns them to `_recipient`, increasing the total amount of shares.
   * @dev This doesn't increase the token total supply.
   *
   * NB: The method doesn't check protocol pause relying on the external enforcement.
   *
   * Requirements:
   *
   * - `_to` cannot be the zero address.
   * - the contract must not be paused.
   */
  function _mintShares(address _to, uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
    if (_to == address(0)) {
      revert LSDai__TransferToZeroAddress();
    }

    newTotalShares = _totalLsdaiShares.add(_sharesAmount);

    /// @todo research a better place for the storage location for the total shares
    _totalLsdaiShares = newTotalShares;

    _shares[_to] = _shares[_to].add(_sharesAmount);
  }

  /**
   * @dev updates the total amount of DAI controlled by LSDai.
   * @param chi If overrideChi is greater than 0, it will use that chi instead of the most recent chi.
   * @param requireSuccess If true, it will revert if the delta pooled DAI underflows or overflows.
   * It also calcuates the fees on the accrued interest and appends them to the protocol fee pot.chi();
   */
  function _rebase(uint256 chi, bool requireSuccess) internal {
    uint256 preRebaseTotalPooledDai = _totalPooledDai;
    // total pooled DAI is the total shares times the chi
    uint256 postRebaseTotalPooledDai = (_totalPotShares * chi) / RMath.RAY;

    // Change in total pooled DAI is the total pooled DAI before fees minus the total pooled DAI after fees
    (bool isOk, uint256 deltaTotalPooledDai) = postRebaseTotalPooledDai.trySub(_totalPooledDai); // Interest earned since last rebase

    // Revert with custom error in event of underflow/overflow
    if (isOk == false && requireSuccess == true) {
      revert LSDai__RebaseOverflow(preRebaseTotalPooledDai, postRebaseTotalPooledDai);
    } else if (isOk == false) {
      return;
    }

    // Update total pooled DAI
    _totalPooledDai = postRebaseTotalPooledDai;

    // Get the fees on accrued interest
    uint256 protocolFeeDaiAmount = _calcInterestFees(deltaTotalPooledDai);

    // Mint LSdai shares to the protocol
    uint256 protocolFeeLsdaiShares = getSharesByPooledDai(protocolFeeDaiAmount);
    _mintShares(feeRecipient, protocolFeeLsdaiShares);
  }

  /**
   * Returns the total supply of LSDAI by converting the DSR shares to DAI
   */
  function _getTotalPooledDai() internal view returns (uint256) {
    return _totalPooledDai;
  }

  /**
   * @dev Calculates the fees on the accrued interest
   * @param _daiAmount The change in total pooled DAI since the last rebase
   */
  function _calcInterestFees(uint256 _daiAmount) internal view returns (uint256 protocolFee) {
    if (interestFee == 0) {
      return 0;
    }

    protocolFee = _daiAmount.mul(interestFee).div(10_000);
  }

  /**
   * @dev returns most recent chi (the rate accumulator) by calling drip if necessary
   */
  function _getMostRecentChi() internal returns (uint256) {
    if (block.timestamp > pot.rho()) {
      return pot.drip();
    }
    return pot.chi();
  }
}
