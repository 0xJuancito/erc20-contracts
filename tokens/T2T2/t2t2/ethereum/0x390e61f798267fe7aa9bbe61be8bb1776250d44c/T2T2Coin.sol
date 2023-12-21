// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.20;
 //0.8.21 9974 shanghai
library SafeMath {
  
  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20{
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns(uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
    */
    function balanceOf(address acount) external view returns(uint256);

    /**
     *  @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded. 
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient,uint256 amount) external returns (bool);
    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner,address spender) external view returns(uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender,uint256 amount)external returns(bool);
   /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */

    function transferFrom(address sender,address recipient,uint256 amount) external returns(bool);

     /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

     /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);


}

interface IERC20Metadata is IERC20 {
     /**
     * @dev Returns the name of the token.
     */
    function name() external view returns(string memory);
    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns(string memory);
    /**
     * @dev Returns the decimals places of the token.
     */ 
    function decimals() external view returns(uint8);
    
}




contract ERC20 is Context, IERC20, IERC20Metadata {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    uint256 private _totalMintedSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory sysmbol_) {
        _name = name_;
        _symbol = sysmbol_;
        _decimals=18;
        _totalSupply =10000000000000000000000000000;
        _totalMintedSupply=0;
    }

    /**
     * @dev Retruns the name of the token.
     *
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

  

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */ /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function _setDecimals(uint8 decimals_) internal virtual{
        _decimals = decimals_;

    }

    function _resetNameErc20(
        string memory name_,
        string memory symbol_
    ) internal virtual {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
     /**
     * @dev See {ERC20-totalSupply}.
     */
    function totalMintedSupply() public view   returns (uint256) {
        return _totalMintedSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
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

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);
        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            // _balances[sender] = senderBalance - amount;
            _balances[sender] = senderBalance.sub(amount);
        }
        // _balances[recipient] += amount;
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalMintedSupply = _totalMintedSupply.add(amount);
        require(_totalMintedSupply<=_totalSupply," totalSupply error ");
        _beforeTokenTransfer(address(0), account, amount);
        _balances[account] = _balances[account].add(amount);
       
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        // require(_totalSupply>=amount, "ERC20: burn not enough _totalSupply");
        _beforeTokenTransfer(account, address(0), amount);
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            // _balances[account] = accountBalance - amount;
            _balances[account] = accountBalance.sub(amount);
        }
        // _totalSupply -= amount;
        _totalMintedSupply = _totalMintedSupply.sub(amount); 
        _totalSupply = _totalSupply.sub(amount);

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

   /**
    * @dev Returns the address of the current owner
    */
   function owner() public view virtual returns(address){
        return _owner;
   }

   /**
    * @dev Throws if called by any account other than the owner    
    */

   modifier onlyOwner(){
      require(owner()==_msgSender(),"Ownable: caller is not the owner");
      _;
   }

  
   /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
   function renounceOwnership() public virtual onlyOwner{
     _setOwner(address(0));
   }


     /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }



  
}

abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


contract Utilities is Ownable,Pausable{
    modifier nonZeroAddress(address _address){
        require(address(0)!=_address,"0 address");
        _;
    }

    modifier nonZeroLength(uint[] memory _array){
         require(_array.length > 0, "Empty array");
         _;

    }

     modifier lengthsAreEqual(uint[] memory _array1, uint[] memory _array2) {
        require(_array1.length == _array2.length, "Unequal lengths");
        _;
    }

    modifier onlyEOA(){
        require(msg.sender==tx.origin,"No contracts");
        _;
    }

    function isOwner() internal view returns(bool)
    {
        return owner()==msg.sender;
    }
}

contract Adminable is Utilities{

    mapping(address=>bool) private admins;
    constructor(){
       
    }
    function addAdmin(address _address) external onlyOwner{        
        admins[_address]=true;
        
    }

    function addAdmins(address[] calldata _addresses) external onlyOwner{
        uint256 len = _addresses.length;
        for(uint256 i=0;i<len;i++)
        {            
            admins[_addresses[i]]=true;
        }
    }

    function removeAdmin(address _address) external onlyOwner{
        admins[_address]=false;
    }

    function removeAdmins(address[] calldata _addresses) external onlyOwner{
        uint256 len = _addresses.length;
        for(uint256 i=0;i<len;i++)
        {            
            admins[_addresses[i]]=false;
        }
    }

    function setPause(bool _shouldPause) external onlyAdminOrOwner{
        if(_shouldPause)
        {
            _pause();
        }else
        {
            _unpause();
        }
    }

    function isAdmin(address _address) public view returns(bool){
        return admins[_address];
    }

    modifier onlyAdmin(){
        require(admins[msg.sender], "Not admin");
        _;
    }

    modifier onlyAdminOrOwner(){
        require(admins[msg.sender]||isOwner(), "Not admin or owner");
        _;
    }
}

contract T2T2Coin is ERC20,Adminable {

  // address => allowedToCallFunctions
  mapping(address => bool) private admins;
  
  constructor() ERC20("T2T2", "T2T2") {    
     
  }


  function setDecimals(uint8 decimals_) external  onlyOwner{
      _setDecimals(decimals_);
  }
 
  function resetNameCoin(string calldata name_,string calldata symbol_) external onlyOwner{
      _resetNameErc20(name_,symbol_);
  }
 


 

  /**
   * mints $T2T2 to a recipient
   * @param to the recipient of the $T2T2
   * @param amount the amount of $T2T2 to mint
   */
  function mint(address to, uint256 amount) external  whenNotPaused onlyAdminOrOwner {    
    require(isAdmin(msg.sender), "T2T2: Only admins can mint");
    _mint(to, amount);
  }



  /**
    * @dev See {IERC20-transferFrom}.
    *
    * Emits an {Approval} event indicating the updated allowance. This is not
    * required by the EIP. See the note at the beginning of {ERC20}.
    *
    * Requirements:
    *
    * - `sender` and `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `amount`.
    * - the caller must have allowance for ``sender``'s tokens of at least
    * `amount`.
    */
  function transferFrom(
      address sender,
      address to,
      uint256 amount
  ) public override  whenNotPaused returns (bool) {
  
    return super.transferFrom(sender, to, amount);
  }


  function balanceOf(address account) public view virtual override   returns (uint256) {
    
    return super.balanceOf(account);
  }

  function transfer(address recipient, uint256 amount) public virtual override  whenNotPaused returns (bool) {   
    return super.transfer(recipient, amount);
  }

  // Not ensuring state changed in this block as it would needlessly increase gas
  function allowance(address owner, address spender) public view virtual override whenNotPaused returns (uint256) {
    return super.allowance(owner, spender);
  }

  // Not ensuring state changed in this block as it would needlessly increase gas
  function approve(address spender, uint256 amount) public virtual override whenNotPaused returns (bool) {
    return super.approve(spender, amount);
  }

  // Not ensuring state changed in this block as it would needlessly increase gas
  function increaseAllowance(address spender, uint256 addedValue) public virtual override whenNotPaused returns (bool) {
    return super.increaseAllowance(spender, addedValue);
  }

  // Not ensuring state changed in this block as it would needlessly increase gas
  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override whenNotPaused returns (bool) {
    return super.decreaseAllowance(spender, subtractedValue);
  }


}