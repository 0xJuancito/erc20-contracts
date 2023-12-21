// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
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
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
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
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
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
        address owner = _msgSender();
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
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
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

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
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
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}
interface IReferral {
  /**
   * @dev Record referral.
   */
  function recordReferralfromLobby(
    address user,
    address referrer,
    uint256 amount,
    uint256 day
  ) external;

  /**
   * @dev Record referral commission.
   */
  function recordReferralCommissionfromLobby(
    address referrer,
    uint256 commission,
    uint256 day
  ) external;

  /**
   * @dev Get the referrer address that referred the user.
   */
  function getReferrer(address user) external view returns (address);
}

interface LotteryInterface {
  function newBuy_hCe(uint256 _amount, address _address) external;
  function drawRaffle_YlX() external returns (address);
}

contract TORR is ERC20, ReentrancyGuard, Ownable {
  event UserEnterLobby(address indexed addr, uint256 timestamp, uint256 entryAmountEth, uint256 day);
  event UserCollectAuctionTokens(address indexed addr, uint256 timestamp, uint256 day, uint256 tokenAmount, uint256 referreeBonus);
  event RefferrerBonusPaid(address indexed referrerAddress, address indexed reffereeAddress, uint256 timestamp, uint256 referrerBonus, uint256 referreeBonus);
  event DailyAuctionEnd(uint256 timestamp, uint256 day, uint256 ethTotal, uint256 tokenTotal);

  /** Taxs */
  address public dev_addr = 0x27D74069B4d7F2b9EeB35D2F6826738fe3EDE423;
  address public Team_addr = 0xF7888d52D1e76f7a62cF1296B592019d909E2f1E;
  address public Vault_addr = 0x06952B65096aD3833BB8C6E6A4F0808C9d00a330;
  address public Lottery_addr;

  /* Gets called once a day and withdraws 10% fees from every day's lobby entry */
  uint256 public dev_percentage = 3;
  uint256 public Team_percentage = 2;
  uint256 public Vault_percentage = 14;
  uint256 public Lottery_percent = 1;

  /* last amount of auction pool that are minted daily to be distributed between lobby participants which starts from 1 mil */
  uint256 public lastAuctionTokens = 100000 * 1e18;

  /* Ref bonuses, referrer is the person who refered referre is person who got referred, includes 1 decimal so 25 = 2.5%  */
  uint256 public referrer_bonus = 20;
  uint256 public referree_bonus = 10;

  uint256 public currentDay;
  uint256 public usersCount;
  uint256 public overall_collectedTokens;
  uint256 public overall_lobbyEntry;

  /* lobby memebrs data */
  struct userAuctionEntry {
    uint256 totalDeposits;
    uint256 day;
    bool hasCollected;
    address referrer;
  }

  /* new map for every entry (users are allowed to enter multiple times a day) */
  mapping(address => mapping(uint256 => userAuctionEntry)) public mapUserAuctionEntry;
  mapping(uint256 => uint256) public usersCountDaily;
  /** Total BTT deposited for the day */
  mapping(uint256 => uint256) public auctionDeposits;

  /** Total tokens minted for the day */
  mapping(uint256 => uint256) public auctionTokens;

  /** The percent to reduce the total tokens by each day 5 = 0.5% */
  uint256 public dailyTokenReductionPercent = 5;

  // Record the contract launch time & current day
  uint256 public LAUNCH_TIME;

  /** External Contracts */
  LotteryInterface public _lotteryContract;
  IReferral public _ReferralContract;
  address public _stakingContract;

  constructor() ERC20('infiniTORR', 'TORR') {}

  receive() external payable {}

  /** 
    @dev is called when we're ready to start the auction
    @param _lotteryAddr address of the lottery contract
    @param _stakingAddr address of the staking contract
    @param _refAddr address of the ref contract
  */
  function startAuction(
    address _lotteryAddr,
    address _stakingAddr,
    address _refAddr
  //  address _VaultAddr
  ) external payable onlyOwner {
    require(LAUNCH_TIME == 0);
    _mint(msg.sender, 40000000 * 1e18);
    LAUNCH_TIME = block.timestamp;
    _lotteryContract = LotteryInterface(_lotteryAddr);
    _stakingContract = _stakingAddr;
    _ReferralContract = IReferral(_refAddr);
    Lottery_addr = _lotteryAddr;
    currentDay = calcDay();
  }

  function updateContracts(
    address _lotteryAddr,
    address _stakingAddr,
    address _refAddr,
    address _VaultAddr
  ) external payable onlyOwner {
    _lotteryContract = LotteryInterface(_lotteryAddr);
    _stakingContract = _stakingAddr;
    _ReferralContract = IReferral(_refAddr);
    Vault_addr = _VaultAddr;
    Lottery_addr = _lotteryAddr;
  }

  /**
    @dev update the bonus paid out to affiliates. 20 = 2%
    @param _referrer the percent going to the referrer
    @param _referree the percentage going to the referee
  */
  function updateReferrerBonus(uint256 _referrer, uint256 _referree) external payable onlyOwner {
    require((_referrer <= 50 && _referree <= 50), 'Over max values');
    require((_referrer != 0 && _referree != 0), 'Cant be zero');
    referrer_bonus = _referrer;
    referree_bonus = _referree;
  }

  /**
    @dev Calculate the current day based off the auction start time 
  */
  function calcDay() public view returns (uint256) {
    if (LAUNCH_TIME == 0) return 0;
    return (block.timestamp - LAUNCH_TIME) / 1 days;
  }

  function doDailyUpdate_Vkx() public {
    uint256 _nextDay = calcDay(); 
    uint256 _currentDay = currentDay; 
 
    if (_currentDay != _nextDay) {
      uint256 _taxShare;
      uint256 _divsShare;

      if (_nextDay > 1) {
        _taxShare = (address(this).balance * tax()) / 100;
        _divsShare = address(this).balance - _taxShare;
        (bool success, ) = address(_stakingContract).call{ value: _divsShare }(abi.encodeWithSignature('receiveDivs_Ch6()'));
        require(success,'unable to receiveDivs_Ch6');
      }

      if (_taxShare != 0) {
        flushTaxes(_taxShare);
      }
      (bool success2, ) = address(_stakingContract).call(abi.encodeWithSignature('flushTaxes_4it()'));
      require(success2,'unable to flushTaxes_4it');

      // Only mint new tokens when we have deposits for that day
      if (auctionDeposits[currentDay] != 0) {
        _mintDailyAuctionTokens(_currentDay);
      }

      if (Lottery_percent != 0) {
        (success2, ) = address(_lotteryContract).call(abi.encodeWithSignature('drawRaffle_YlX()'));
        require(success2);
      }

      emit DailyAuctionEnd(block.timestamp, currentDay, auctionDeposits[currentDay], auctionTokens[currentDay]);
      currentDay = _nextDay;

    }
  }

  /**
    @dev The total of all the taxs
  */
  function tax() public view returns (uint256) {
    return Lottery_percent + dev_percentage + Team_percentage + Vault_percentage;
  }

  /**
        @dev Send all the taxs to the correct wallets
        @param _amount total BTT to distro
    */
  function flushTaxes(uint256 _amount) public {
    uint256 _devTax;
    uint256 _totalTax = tax();
    uint256 _TeamTax = (_amount * Team_percentage) / _totalTax;
    uint256 _VaultTax = (_amount * Vault_percentage) / _totalTax;
    uint256 _LottoTax = (_amount * Lottery_percent) / _totalTax;

    if (_amount>(_TeamTax + _VaultTax + _LottoTax)) {
       _devTax = _amount - (_TeamTax + _VaultTax + _LottoTax);
        } else {
       _devTax = 0;   
    }
        (bool sent,) = dev_addr.call{value: _devTax}("");
        require(sent, "Failed to send Ether1");
          ( sent,) = Team_addr.call{value: _TeamTax}("");
        require(sent, "Failed to send Ether2");
          ( sent,) = Vault_addr.call{value: _VaultTax}("");
        require(sent, "Failed to send Ether3");
          ( sent,) = Lottery_addr.call{value:_LottoTax}("");
        require(sent, "Failed to send Ether4");
  }
 
  /**
    @dev Send all the taxs to the correct wallets for day 0 only
    @param _amount total BTT to distribute
  */
  function flushTaxesDay0(uint256 _amount) internal {
    uint256 _devTax;
    uint256 _TeamTax = ((_amount * 10) / 100);
    uint256 _VaultTax = ((_amount * 75) / 100);

     if (_amount>(_TeamTax + _VaultTax)) {
    _devTax = _amount - (_TeamTax + _VaultTax);
        } else {
       _devTax = 0;   
    }
    (bool sent,) = dev_addr.call{value: _devTax}("");
    require(sent, "Failed to send Ether11");
      ( sent,) = Team_addr.call{value: _TeamTax}("");
    require(sent, "Failed to send Ether12");
      ( sent,) = Vault_addr.call{value: _VaultTax}("");
    require(sent, "Failed to send Ether13");

  }

  /**
    @dev UPdate  the taxes, can't be greater than current taxes
    @param _dev the dev tax
    @param _Team the Team tax
    @param _Vault the Vault tax
    @param _lottery biggest buy comp tax
  */
  function updateTaxes(
    uint256 _dev,
    uint256 _Team,
    uint256 _Vault,
    uint256 _lottery
  ) external onlyOwner {
     dev_percentage = _dev;
    Team_percentage = _Team;
    Vault_percentage = _Vault;
    Lottery_percent = _lottery;
  }

  /**
        @dev Update the Team wallet address
    */
  function updateTeamAddress(address adr) external payable onlyOwner {
    Team_addr = adr;
  }

  /**
        @dev Update the dev wallet address
    */
  function updateDevAddress(address adr) external payable onlyOwner {
    dev_addr = adr;
  }

  /**
        @dev update the Vault wallet address
    */
  function updateVaultAddress(address adr) external payable onlyOwner {
    Vault_addr = adr;
  }

  function mintBonus(address to, uint256 amount) external {
    require(msg.sender == address(_stakingContract));
    _mint(to, amount);
  }

  /**
    @dev Mint the auction tokens for the day 
    @param _day the day to mint the tokens for
  */
  function _mintDailyAuctionTokens(uint256 _day) internal {
    uint256 _nextAuctionTokens;
    if (_day == 0) {
      _nextAuctionTokens = 100000 * 1e18;
    } else {
      _nextAuctionTokens = todayAuctionTokens(); 
    }
    _mint(address(this), _nextAuctionTokens);
    auctionTokens[_day] = _nextAuctionTokens;
    lastAuctionTokens = _nextAuctionTokens;
  }

  function todayAuctionTokens() public view returns (uint256) {
    return lastAuctionTokens - ((lastAuctionTokens * dailyTokenReductionPercent) / 1000);
  }

  /**
   * @dev entering the auction lobby for the current day
   * @param referrerAddr address of referring user (optional; 0x0 for no referrer)
  */
  function EnterLobby_B4Y(address referrerAddr) external payable {
    require((LAUNCH_TIME != 0 && msg.value != 0));
    require(calcDay() < 120, 'lobby over');
    doDailyUpdate_Vkx();
    uint256 _currentDay = currentDay;

    auctionDeposits[_currentDay] += msg.value;
    overall_lobbyEntry += msg.value;

    if (mapUserAuctionEntry[msg.sender][_currentDay].totalDeposits == 0) {
      usersCount++;
      usersCountDaily[currentDay]++;
    }

    mapUserAuctionEntry[msg.sender][_currentDay] = userAuctionEntry({
      totalDeposits: mapUserAuctionEntry[msg.sender][_currentDay].totalDeposits + msg.value,
      day: _currentDay,
      hasCollected: false,
      referrer: (referrerAddr != msg.sender) ? referrerAddr : address(0)
    });

    if (referrerAddr != msg.sender) {
      _ReferralContract.recordReferralfromLobby(msg.sender, referrerAddr, msg.value, _currentDay);
    }

    if (_currentDay == 0) {
      flushTaxesDay0(msg.value);
    }

    if (Lottery_percent != 0) {
      _lotteryContract.newBuy_hCe(msg.value, msg.sender);
    }

    emit UserEnterLobby(msg.sender, block.timestamp, msg.value, _currentDay);
  }

  /**
   * @dev External function for leaving the lobby / collecting the tokens
   * @param targetDay Target day of lobby to collect
   */
  function ExitLobby_418w(uint256 targetDay) external nonReentrant {
    doDailyUpdate_Vkx();
    require(mapUserAuctionEntry[msg.sender][targetDay].hasCollected == false);
    require(targetDay < currentDay, 'cant collect tokens for current active day');

    uint256 _tokensToPay = _clcTokenValue(msg.sender, targetDay);

    mapUserAuctionEntry[msg.sender][targetDay].hasCollected = true;
    _transfer(address(this), msg.sender, _tokensToPay);

    address _referrerAddress = mapUserAuctionEntry[msg.sender][targetDay].referrer;
    uint256 _referreeBonus;

    if (_referrerAddress != address(0)) {
      /* there is a referrer, pay their % ref bonus of tokens */
      uint256 _reffererBonus = (_tokensToPay * referrer_bonus) / 1000;
      _referreeBonus = (_tokensToPay * referree_bonus) / 1000;

      _ReferralContract.recordReferralCommissionfromLobby(_referrerAddress, _reffererBonus, targetDay);

      _mint(_referrerAddress, _reffererBonus);
      _mint(msg.sender, _referreeBonus);

      emit RefferrerBonusPaid(_referrerAddress, msg.sender, block.timestamp, _reffererBonus, _referreeBonus);
    }

    overall_collectedTokens += _tokensToPay;

    emit UserCollectAuctionTokens(msg.sender, block.timestamp, targetDay, _tokensToPay, _referreeBonus);
  }

  /**
   * @dev Calculating user's share from lobby based on their & of deposits for the day
   * @param _Day The lobby day
   */
  function _clcTokenValue(address _address, uint256 _Day) public view returns (uint256) {
    uint256 _tokenValue;
    uint256 _entryDay = mapUserAuctionEntry[_address][_Day].day;

    if (auctionTokens[_entryDay] == 0) return 0;

    _tokenValue = (auctionTokens[_entryDay] * mapUserAuctionEntry[_address][_Day].totalDeposits) / auctionDeposits[_entryDay];

    return _tokenValue;
  }

  /**
    @dev change the % reduction of the daily tokens minted
    @param _val the new percent val 3% = 30
  */
  function updateDailyReductionPercent(uint256 _val) external payable onlyOwner {
    // must be >= 1% and <= 6%
    require((_val >= 10 && _val <= 60));
    dailyTokenReductionPercent = _val;
  }

  function getStatsNew() external view returns (uint256[5] memory amounts) {
    return amounts = [calcDay(), usersCount, overall_lobbyEntry, todayAuctionTokens(), overall_collectedTokens];
  }

  function getStatsLoop(uint256 _day)
    external
    view
    returns (
      uint256 yourDeposit,
      uint256 totalDeposits,
      uint256 youReceive,
      bool claimedis
    )
  {
    yourDeposit = mapUserAuctionEntry[msg.sender][_day].totalDeposits;
    totalDeposits = auctionDeposits[_day];
    youReceive = _clcTokenValue(msg.sender, _day);
    claimedis = mapUserAuctionEntry[msg.sender][_day].hasCollected;
  }

  function getStatsLoops(
    uint256 _day,
    uint256 numb,
    address account
  )
    external
    view
    returns (
      uint256[10] memory yourDeposits,
      uint256[10] memory totalDeposits,
      uint256[10] memory youReceives,
      bool[10] memory claimedis
    )
  {
    for (uint256 i = 0; i < numb; ) {
      yourDeposits[i] = mapUserAuctionEntry[account][_day + i].totalDeposits;
      totalDeposits[i] = auctionDeposits[_day + i];
      youReceives[i] = _clcTokenValue(account, _day + i);
      claimedis[i] = mapUserAuctionEntry[account][_day + i].hasCollected;
      unchecked {
        ++i;
      }
    }
    return (yourDeposits, totalDeposits, youReceives, claimedis);
  }
}