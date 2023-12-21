// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import  "./IBEP20.sol";
import  "./Ownable.sol";
import  "./SafeMath.sol";

contract BEP20 is Context, IBEP20, Ownable {
  using SafeMath for uint256;
  uint256 constant thirtyDays = 2592000;
  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  uint256 private _totalSupply;
  uint256 immutable private _maxSupply;
  uint256 private _monthlySupply;
  uint256 private _maxMonthlySupply;
  uint8   private _decimals;
  string  private _symbol;
  string  private _name;
  uint256 private _startTime;
  address private _subventionAdd;

  constructor(address subventionAdd)  {
    _name                 = "SYL";
    _symbol               = "SYL";
    _decimals             = 6;
    _totalSupply          = 7000000000 * (10 ** uint256(_decimals)); //(70%) => 7 MD
    _balances[msg.sender] = _totalSupply;
    _startTime            = 1617141600; // 31 Mars 2021  00:00:00
    _maxMonthlySupply     = 60000000 * (10 ** uint256(_decimals)); // 60 MN SYL
    _maxSupply            = 10000000000 * (10 ** uint256(_decimals)); // 10 MD
    _subventionAdd        = subventionAdd;
    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  /**
   * @dev Returns the bep token owner.
   */
  function getOwner() public view  override returns (address) {
    return owner();
  }
  /**
   * @dev Returns the subventionAdd.
   */
  function getSubventionAdd() external view returns (address) {
    return _subventionAdd;
  }

  /**
   * @dev Returns the token decimals.
   */
  function decimals() public view  override returns (uint8) {
    return _decimals;
  }

  /**
   * @dev Returns the token symbol.
   */
  function symbol() public view  override returns (string memory) {
    return _symbol;
  }

  /**
  * @dev Returns the token name.
  */
  function name() public view  override returns (string memory) {
    return _name;
  }

  /**
   * @dev See {BEP20-totalSupply}.
   */
  function totalSupply() public view  override returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev See {BEP20-balanceOf}.
   */
  function balanceOf(address account) public view  override returns (uint256) {
    return _balances[account];
  }

  /**
   * @dev Returns the cap on the token's total supply.
   */
   function maxSupply() public view  returns (uint256) {
       return _maxSupply;
   }

  /**
   * @dev Returns the max monthly cap.
   */
   function maxMonthlySupply() public view  returns (uint256) {
      return _maxMonthlySupply;
   }
  /**
   * @dev See {BEP20-monthlySupply}.
   */
   function monthlySupply() external view returns (uint256) {
    return _monthlySupply;
   }
  /**
   * @dev See {BEP20-startTime}.
   */
   function startTime() external view returns (uint256) {
      return _startTime;
   }
   /**
    * @dev See _maxMonthlySupply - _monthlySupply.
    */
    function getRestToBeMinted() external view returns (uint256) {
      return _maxMonthlySupply.sub(_monthlySupply);
    }
  /**
   * @dev See {BEP20-transfer}.
   *
   * Requirements:
   *
   * - `recipient` cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   */
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  /**
   * @dev See {BEP20-allowance}.
   */
  function allowance(address owner, address spender) public view  override returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
   * @dev See {BEP20-approve}.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(address spender, uint256 amount) public virtual  override returns (bool) {
    _approve(_msgSender(), spender, amount);
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
  function transferFrom(address sender, address recipient, uint256 amount) public virtual  override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
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
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
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
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

  /**
   * @dev Creates `amount` tokens and assigns them to `subventionAdd`, increasing
   * the total supply and the monthlySupply (will be set to 0 after 30 days from the start time).
   * Every 30 days we can creates at max 60 MN
   *
   * See {ERC20-_mint}.
   */
  function mint(uint256 amount) public onlyOwner returns (bool) {
    if ( block.timestamp > _startTime.add(thirtyDays)){
        _monthlySupply = 0;
        _startTime = _startTime.add(thirtyDays);
    }
    if ( block.timestamp >= _startTime){
        require(_monthlySupply.add(amount) <= maxMonthlySupply(), "BEP20: monthly cap exceeded");
        require(_totalSupply.add(amount) <= maxSupply(), "BEP20: cap exceeded");
        _mint(_subventionAdd, amount);
        _monthlySupply = _monthlySupply.add(amount);
    }
    return true;
  }


  /**
    * @dev Destroys `amount` tokens from the caller.
    *
    * See {ERC20-_burn}.
    */
  function burn(uint256 amount) public onlyOwner returns (bool) {
    _burn(_msgSender(), amount);
    return true;
  }

  /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public returns (bool) {
        _burnFrom(account, amount);
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
  function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    require(sender != address(0), "BEP20: transfer from the zero address");
    require(recipient != address(0), "BEP20: transfer to the zero address");
    // condition  chaque mois

    _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  /** @dev Creates `amount` tokens and assigns them to `account`, increasing
   * the total supply.
   *
   * Emits a {Transfer} event with `from` set to the zero address.
   *
   * Requirements
   *
   * - `to` cannot be the zero address.
   */
  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: mint to the zero address");

    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`, reducing the
   * total supply.
   *
   * Emits a {Transfer} event with `to` set to the zero address.
   *
   * Requirements
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens.
   */
  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: burn from the zero address");

    _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
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
  function _approve(address owner, address spender, uint256 amount) internal virtual {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
   * from the caller's allowance.
   *
   * See {_burn} and {_approve}.
   */
  function _burnFrom(address account, uint256 amount) internal {
    _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "BEP20: burn amount exceeds allowance"));
    _burn(account, amount);
  }


}
