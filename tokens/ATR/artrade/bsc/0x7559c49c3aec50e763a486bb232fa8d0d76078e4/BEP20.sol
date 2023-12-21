// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import  "./IBEP20.sol";
import  "./Ownable.sol";
import  "./SafeMath.sol";

contract BEP20 is Context, IBEP20, Ownable {
  using SafeMath for uint256;
  uint256 constant thirtyDays = 2592000;
  uint256 constant cliffSixM       = 6;
  uint256 constant cliffFourM      = 4;
  uint256 constant cliffThreeM     = 3;
  uint256 constant cliffTwoM       = 2;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  uint256 private _totalSupply;
  uint256 private _totalSupply_6M;
  uint256 private _totalSupply_4M;
  uint256 private _totalSupply_3M;
  uint256 private _totalSupply_2M;

  bool    private _initialMintIsDone;
  bool    private _authoriseMin_6M;
  bool    private _authoriseMin_4M;
  bool    private _authoriseMin_3M;
  bool    private _authoriseMin_2M;

  uint256 immutable private _maxSupply;
  uint256 immutable private _maxSupply_6M;
  uint256 immutable private _maxSupply_4M;
  uint256 immutable private _maxSupply_3M;
  uint256 immutable private _maxSupply_2M;

  uint256 private _wallet1MonthlySupply;
  uint256 private _wallet2MonthlySupply;
  uint256 private _wallet3MonthlySupply;
  uint256 private _wallet4MonthlySupply;
  uint256 private _wallet5MonthlySupply;
  uint256 private _wallet6MonthlySupply;


  uint256 private _wallet1EndOfIcoSupply;
  uint256 private _wallet2EndOfIcoSupply;
  uint256 private _wallet3EndOfIcoSupply;
  uint256 private _wallet4EndOfIcoSupply;
  uint256 private _wallet5EndOfIcoSupply;
  uint256 private _wallet6EndOfIcoSupply;

  uint8   private _decimals;
  string  private _symbol;
  string  private _name;

  uint256 private _endOfICO;

  uint256 private _startTime_2M;
  uint256 private _startTime_3M;
  uint256 private _startTime_4M;
  uint256 private _startTime_6M;

  address private _wallet1;
  address private _wallet2;
  address private _wallet3;
  address private _wallet4;
  address private _wallet5;
  address private _wallet6;

  constructor(address wallet1, address wallet2, address wallet3,address wallet4, address wallet5, address wallet6)  {
    _name                 = "Artrade Token";
    _symbol               = "ATR";
    _decimals             = 9;
    _balances[msg.sender] = 0;

    _endOfICO             = block.timestamp; 
    _startTime_2M         = _endOfICO + (thirtyDays * 2); // 2 month after
    _startTime_3M         = _endOfICO + (thirtyDays * 3); // 3 month after
    _startTime_4M         = _endOfICO + (thirtyDays * 5); // 5 month after
    _startTime_6M         = _endOfICO + (thirtyDays * 7); // 7 month after

    _wallet1MonthlySupply        = 4739256671          * (10 ** uint256(7)); //
    _wallet2MonthlySupply        = 21962955            * (10 ** uint256(_decimals)); //
    _wallet3MonthlySupply        = 6967485             * (10 ** uint256(_decimals)); //
    _wallet4MonthlySupply        = 112052348683481     * (10 ** uint256(2)); //
    _wallet5MonthlySupply        = 151894456           * (10 ** uint256(8)); //



    _wallet1EndOfIcoSupply       = 21326655022   * (10 ** uint256(7));
    _wallet2EndOfIcoSupply       = 20807010     * (10 ** uint256(_decimals));
    _wallet3EndOfIcoSupply       = 9289980      * (10 ** uint256(_decimals));
    _wallet4EndOfIcoSupply       = 112052347899114    * (10 ** uint256(2));
    _wallet5EndOfIcoSupply       = 151894456    * (10 ** uint256(8));
    _wallet6EndOfIcoSupply       = 70243377     * (10 ** uint256(_decimals));


    _maxSupply_6M         = 1482472951  * (10 ** uint256(_decimals));
    _maxSupply_4M         = 92899800    * (10 ** uint256(_decimals));
    _maxSupply_3M         = 78436644    * (10 ** uint256(_decimals));
    _maxSupply_2M         = 75947228    * (10 ** uint256(_decimals));

    _maxSupply            = 1800000000 * (10 ** uint256(_decimals)); // 1,8 MD

    _initialMintIsDone    = false;


    _wallet1        = wallet1;
    _wallet2        = wallet2;
    _wallet3        = wallet3;
    _wallet4        = wallet4;
    _wallet5        = wallet5;
    _wallet6        = wallet6;

    _mint(_wallet1, _wallet1EndOfIcoSupply);
    _mint(_wallet2, _wallet2EndOfIcoSupply);
    _mint(_wallet3, _wallet3EndOfIcoSupply);
    _mint(_wallet4, _wallet4EndOfIcoSupply);
    _mint(_wallet5, _wallet5EndOfIcoSupply);
    _mint(_wallet6, _wallet6EndOfIcoSupply);
    _totalSupply_2M   = _totalSupply_2M.add(_wallet5EndOfIcoSupply);
    _totalSupply_3M   = _totalSupply_3M.add(_wallet4EndOfIcoSupply);
    _totalSupply_4M   = _totalSupply_4M.add(_wallet3EndOfIcoSupply);
    _totalSupply_6M   = _totalSupply_6M.add(_wallet1EndOfIcoSupply).add(_wallet2EndOfIcoSupply);

    _totalSupply.add(_wallet1EndOfIcoSupply).add(_wallet2EndOfIcoSupply).add(_wallet3EndOfIcoSupply).add(_wallet4EndOfIcoSupply).add(_wallet5EndOfIcoSupply).add(_wallet6EndOfIcoSupply);
  }

  /**
   * @dev Returns the bep token owner.
   */
  function getOwner() public view  override returns (address) {
    return owner();
  }
  /**
   * @dev Returns  Round 3 address.
   */
  function getRound3Add() external view returns (address) {
    return _wallet6;
  }

  /**
   * @dev Returns  Round 2 address.
   */
  function getRaound2Add() external view returns (address) {
    return _wallet5;
  }

  /**
   * @dev Returns  Round 1  address.
   */
  function getRound1Add() external view returns (address) {
    return _wallet4;
  }

  /**
   * @dev Returns  Private Sale address.
   */
  function getPrivateSaleAdd() external view returns (address) {
    return _wallet3;
  }

  /**
   * @dev Returns  Team and Associates address.
   */
  function getTeamAdd() external view returns (address) {
    return _wallet2;
  }

  /**
   * @dev Returns  reserve address.
   */
  function getReserveAdd() external view returns (address) {
    return _wallet1;
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
   * @dev Returns the end of ico .
   */
   function getEndOfICO() public view  returns (uint256) {
       return _endOfICO;
   }

  /**
   * @dev See {BEP20-startTime}.
   */
   function startTime() external view returns (uint256) {
      return _endOfICO;
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

  /** @dev Creates `amount` tokens and assigns them to the right
	 * adresses (associatesAdd, teamAdd, seedAdd, privSaleAdd,
	 * marketingAdd, icoRound1Add , icoRound2Add, icoRound3Add,
	 * reserveAdd), increasing _totalSupply_XM sub-supplies and
	 * the total supply
  */
  function mint(uint256 mintValue) public onlyOwner returns (bool) {
        require(( mintValue == cliffSixM) ||  ( mintValue == cliffFourM) || ( mintValue == cliffThreeM) || ( mintValue == cliffTwoM), "BEP20: mint value not authorized");
        if ( mintValue == cliffSixM){
            require(block.timestamp >= _startTime_6M , "BEP20: too early for minting request");
            require(_totalSupply_6M.add(_wallet1MonthlySupply).add(_wallet2MonthlySupply) <= _maxSupply_6M, "BEP20: Assocites, Reserve, Team and Seed cap exceeded");
            require(_totalSupply.add(_wallet1MonthlySupply).add(_wallet2MonthlySupply) <= maxSupply(), "BEP20: cap exceeded");
            _mint(_wallet1, _wallet1MonthlySupply);
            _mint(_wallet2, _wallet2MonthlySupply);
            _totalSupply_6M   = _totalSupply_6M.add(_wallet1MonthlySupply).add(_wallet2MonthlySupply);
            _startTime_6M     = _startTime_6M.add(thirtyDays);   
        }
        if ( mintValue == cliffFourM){
            require(block.timestamp >= _startTime_4M , "BEP20: too early for minting request");
            require(_totalSupply_4M.add(_wallet3MonthlySupply) <= _maxSupply_4M, "BEP20: Marketing and Private Sale cap exceeded");
            require(_totalSupply.add(_wallet3MonthlySupply) <= maxSupply(), "BEP20: cap exceeded");
            _mint(_wallet3, _wallet3MonthlySupply);
            _totalSupply_4M   = _totalSupply_4M.add(_wallet3MonthlySupply);
            _startTime_4M     = _startTime_4M.add(thirtyDays);  
        }
        if ( mintValue == cliffThreeM){
            require(block.timestamp >= _startTime_3M, "BEP20: too early for minting request");
            require(_totalSupply_3M.add(_wallet4MonthlySupply)<= _maxSupply_3M, "BEP20: ICO Round 1 cap exceeded");
            require(_totalSupply.add(_wallet4MonthlySupply) <= maxSupply(), "BEP20: cap exceeded");
            _mint(_wallet4, _wallet4MonthlySupply);
            _totalSupply_3M   = _totalSupply_3M.add(_wallet4MonthlySupply);
            _startTime_3M     = _startTime_3M.add(thirtyDays);
        }
        if ( mintValue == cliffTwoM){
            require(block.timestamp >= _startTime_2M, "BEP20: too early for minting request");
            require(_totalSupply_2M.add(_wallet5MonthlySupply)<= _maxSupply_2M, "BEP20: ICO Round 2 cap exceeded");
            require(_totalSupply.add(_wallet5MonthlySupply) <= maxSupply(), "BEP20: cap exceeded");
            _mint(_wallet5, _wallet5MonthlySupply);
            _totalSupply_2M   = _totalSupply_2M.add(_wallet5MonthlySupply);
            _startTime_2M     = _startTime_2M.add(thirtyDays);
        }
    return true;
  }


  /**
    * @dev Destroys `amount` tokens from the caller.
    *
    * See {ERC20-_burn}.
    */
  function burn(uint256 amount) public  returns (bool) {
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
