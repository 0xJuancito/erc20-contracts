pragma solidity 0.8.4;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './lib/SafeMathint.sol';
import './Interfaces/IMintableToken.sol';
import './Orchestrator.sol';

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract Static is Context, IERC20, Orchestrator, IMintableToken {
	using SafeMath for uint256;
	using SafeMathInt for int256;

	bytes32 public constant rebaserRole = keccak256('rebaser');
	bytes32 public constant minterRole = keccak256('minter');
	bytes32 public constant excluderRole = keccak256('excluder');

	uint256 private constant MAX_UINT256 = ~uint256(0);
	uint256 private constant MAX_SUPPLY = ~uint128(0);
	uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 0; // = 100 * 10**10 * (10**18);
	uint256 public TOTAL_GONS;
	uint256 private _gonsPerFragment = 10**18;

	bool public rebaseAllowed = true;

	mapping(address => uint256) private _balances;

	mapping(address => mapping(address => uint256)) private _allowances;

	mapping(address => bool) private _isExcluded;
	address[] public excluded;

	uint256 private _totalSupply;
	string private _name;
	string private _symbol;
	uint8 private _decimals;

	event LogRebase(uint256 indexed epoch, uint256 totalSupply);
	event GrantExclusion(address indexed account);
	event RevokeExclusion(address indexed account);

	function disableRebase() external onlyRole(DEFAULT_ADMIN_ROLE) {
		rebaseAllowed = false;
	}

	function rebase(uint256 epoch, int256 supplyDelta)
		external
		onlyRole(rebaserRole)
		returns (uint256)
	{
		require(rebaseAllowed, 'Rebase is not allowed');
		uint256 prevRebaseSupply = rebaseSupply();
		uint256 prevTotalSupply = _totalSupply;

		uint256 total = _rebase(supplyDelta);

		emit LogRebase(epoch, total);

		//notify downstream consumers about rebase
		_notifyRebase(
			prevRebaseSupply,
			rebaseSupply(),
			prevTotalSupply,
			_totalSupply
		);

		return total;
	}

	/**
	 * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
	 * a default value of 18.
	 *
	 * To select a different value for {decimals}, use {_setupDecimals}.
	 *
	 * All three of these values are immutable: they can only be set once during
	 * construction.
	 */
	constructor(string memory name_, string memory symbol_) {
		_name = name_;
		_symbol = symbol_;
		_decimals = 18;
		_totalSupply = INITIAL_FRAGMENTS_SUPPLY;
		//_balances[msg.sender] = TOTAL_GONS;
		//_gonsPerFragment = 0;  //TOTAL_GONS.div(_totalSupply);
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	}

	/**
	 * @dev Returns the name of the token.
	 */
	function name() external view returns (string memory) {
		return _name;
	}

	/**
	 * @dev Returns the symbol of the token, usually a shorter version of the
	 * name.
	 */
	function symbol() external view returns (string memory) {
		return _symbol;
	}

	/**
	 * @dev Returns the number of decimals used to get its user representation.
	 * For example, if `decimals` equals `2`, a balance of `505` tokens should
	 * be displayed to a user as `5,05` (`505 / 10 ** 2`).
	 *
	 * Tokens usually opt for a value of 18, imitating the relationship between
	 * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
	 * called.
	 *
	 * NOTE: This information is only used for _display_ purposes: it in
	 * no way affects any of the arithmetic of the contract, including
	 * {IERC20-balanceOf} and {IERC20-transfer}.
	 */
	function decimals() external view returns (uint8) {
		return _decimals;
	}

	/**
	 * @dev See {IERC20-totalSupply}.
	 */
	function totalSupply() public view override returns (uint256) {
		return _totalSupply;
	}

	/**
	 * @dev Exposes the supply available for rebasing. Essentially this is total supply minus excluded accounts
	 * @return rebaseSupply The supply available for rebase
	 */
	function rebaseSupply() public view returns (uint256) {
		uint256 excludedSupply = 0;
		for (uint256 i = 0; i < excluded.length; i++) {
			excludedSupply = excludedSupply.add(balanceOf(excluded[i]));
		}
		return _totalSupply.sub(excludedSupply);
	}

	/**
	 * @dev See {IERC20-balanceOf}.
	 */
	function balanceOf(address account) public view override returns (uint256) {
		if (_gonsPerFragment == 0) return 0;
		return _balances[account].div(_gonsPerFragment);
	}

	/**
	 * @dev See {IERC20-transfer}.
	 *
	 * Requirements:
	 *
	 * - `recipient` cannot be the zero address.
	 * - the caller must have a balance of at least `amount`.
	 */
	function transfer(address recipient, uint256 amount)
		public
		virtual
		override
		returns (bool)
	{
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

	/**
	 * @dev See {IERC20-allowance}.
	 */
	function allowance(address owner, address spender)
		public
		view
		virtual
		override
		returns (uint256)
	{
		return _allowances[owner][spender];
	}

	/**
	 * @dev See {IERC20-approve}.
	 *
	 * Requirements:
	 *
	 * - `spender` cannot be the zero address.
	 */
	function approve(address spender, uint256 amount)
		public
		virtual
		override
		returns (bool)
	{
		_approve(_msgSender(), spender, amount);
		return true;
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
		address recipient,
		uint256 amount
	) public virtual override returns (bool) {
		_transfer(sender, recipient, amount);
		_approve(
			sender,
			_msgSender(),
			_allowances[sender][_msgSender()].sub(
				amount,
				'ERC20: transfer amount exceeds allowance'
			)
		);
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
	function increaseAllowance(address spender, uint256 addedValue)
		external
		virtual
		returns (bool)
	{
		_approve(
			_msgSender(),
			spender,
			_allowances[_msgSender()][spender].add(addedValue)
		);
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
	function decreaseAllowance(address spender, uint256 subtractedValue)
		external
		virtual
		returns (bool)
	{
		_approve(
			_msgSender(),
			spender,
			_allowances[_msgSender()][spender].sub(
				subtractedValue,
				'ERC20: decreased allowance below zero'
			)
		);
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
	function _transfer(
		address sender,
		address recipient,
		uint256 amount
	) internal virtual {
		require(sender != address(0), 'ERC20: transfer from the zero address');
		require(recipient != address(0), 'ERC20: transfer to the zero address');

		// _beforeTokenTransfer(sender, recipient, amount);

		uint256 gonValue = amount.mul(_gonsPerFragment);
		_balances[sender] = _balances[sender].sub(
			gonValue,
			'ERC20: transfer amount exceeds balance'
		);
		_balances[recipient] = _balances[recipient].add(gonValue);
		emit Transfer(sender, recipient, amount);
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
		require(owner != address(0), 'ERC20: approve from the zero address');
		require(spender != address(0), 'ERC20: approve to the zero address');

		_allowances[owner][spender] = amount;
		emit Approval(owner, spender, amount);
	}

	/**
	 * @dev Notifies Fragments contract about a new rebase cycle.
	 * @param supplyDelta The number of new fragment tokens to add into circulation via expansion.
	 * Return The total number of fragments after the supply adjustment.
	 */
	function _rebase(int256 supplyDelta) internal virtual returns (uint256) {
		// if supply delta is 0 nothing to rebase
		// if rebaseSupply is 0 nothing can be rebased
		if (supplyDelta == 0 || rebaseSupply() == 0) {
			return _totalSupply;
		}

		uint256[] memory excludedBalances = _burnExcludedAccountTokens();

		if (supplyDelta < 0) {
			_totalSupply = _totalSupply.sub(uint256(supplyDelta.abs()));
		} else {
			_totalSupply = _totalSupply.add(uint256(supplyDelta));
		}

		if (_totalSupply > MAX_SUPPLY) {
			_totalSupply = MAX_SUPPLY;
		}

		_gonsPerFragment = TOTAL_GONS.div(_totalSupply);

		_mintExcludedAccountTokens(excludedBalances);

		return _totalSupply;
	}

	function mint(address recipient_, uint256 amount_)
		external
		override
		onlyRole(minterRole)
		returns (bool)
	{
		uint256 balanceBefore = balanceOf(recipient_);
		_mint(recipient_, amount_, true);
		uint256 balanceAfter = balanceOf(recipient_);
		return balanceAfter > balanceBefore;
	}

	function _mint(
		address recipient_,
		uint256 amount_,
		bool emitEvent
	) private {
		require(
			recipient_ != address(0),
			'ERC20: transfer to the zero address'
		);
		require(amount_ > 0, "ERC20: Can't mint 0 tokens");

		TOTAL_GONS = TOTAL_GONS.add(_gonsPerFragment.mul(amount_));
		_totalSupply = _totalSupply.add(amount_);

		_balances[recipient_] = _balances[recipient_].add(
			amount_.mul(_gonsPerFragment)
		);

		if (emitEvent) emit Transfer(address(0), recipient_, amount_);
	}

	function burnFrom(address account, uint256 amount) external virtual {
		uint256 currentAllowance = allowance(account, _msgSender());
		require(
			currentAllowance >= amount,
			'ERC20: burn amount exceeds allowance'
		);
		unchecked {
			_approve(account, _msgSender(), currentAllowance - amount);
		}
		_burn(account, amount, true);
	}

	function _burn(
		address account,
		uint256 amount,
		bool emitEvent
	) internal virtual {
		require(account != address(0), 'ERC20: burn from the zero address');

		uint256 accountBalance = _balances[account];
		require(
			accountBalance >= amount.mul(_gonsPerFragment),
			'ERC20: burn amount exceeds balance'
		);
		unchecked {
			_balances[account] = _balances[account].sub(
				amount.mul(_gonsPerFragment)
			);
		}

		TOTAL_GONS = TOTAL_GONS.sub(_gonsPerFragment.mul(amount));
		_totalSupply = _totalSupply.sub(amount);

		if (emitEvent) {
			emit Transfer(account, address(0), amount);
		}
	}

	/* ========== EXCLUSION LIST FUNCTIONS ========== */

	function isExcluded(address account) external view returns (bool) {
		return _isExcluded[account];
	}

	function numExcluded() external view returns (uint256) {
		return excluded.length;
	}

	/**
	 * @dev Grant an exclusion from rebases
	 * @param account The account to grant exclusion
	 *
	 * Requirements:
	 *
	 * - `account` must NOT already be excluded.
	 * - can only be called by `excluderRole`
	 */
	function grantRebaseExclusion(address account)
		external
		onlyRole(excluderRole)
	{
		require(!_isExcluded[account], 'Account is already excluded');
		require(excluded.length <= 100, 'Too many excluded accounts');
		_isExcluded[account] = true;
		excluded.push(account);
		emit GrantExclusion(account);
	}

	/**
	 * @dev Revokes an exclusion from rebases
	 * @param account The account to revoke
	 *
	 * Requirements:
	 *
	 * - `account` must already be excluded.
	 * - can only be called by `excluderRole`
	 */
	function revokeRebaseExclusion(address account)
		external
		onlyRole(excluderRole)
	{
		require(_isExcluded[account], 'Account is not already excluded');
		for (uint256 i = 0; i < excluded.length; i++) {
			if (excluded[i] == account) {
				excluded[i] = excluded[excluded.length - 1];
				_isExcluded[account] = false;
				excluded.pop();
				emit RevokeExclusion(account);
				return;
			}
		}
	}

	/**
	 * @dev Burns all tokens from excluded accounts
	 * @return excludedBalances The excluded account balances before burn
	 */
	function _burnExcludedAccountTokens()
		private
		returns (uint256[] memory excludedBalances)
	{
		excludedBalances = new uint256[](excluded.length);
		for (uint256 i = 0; i < excluded.length; i++) {
			address account = excluded[i];
			uint256 balance = balanceOf(account);
			excludedBalances[i] = balance;
			if (balance > 0) _burn(account, balance, false);
		}

		return excludedBalances;
	}

	/**
	 * @dev Mints tokens to excluded accounts
	 * @param excludedBalances The amount of tokens to mint per address
	 */
	function _mintExcludedAccountTokens(uint256[] memory excludedBalances)
		private
	{
		for (uint256 i = 0; i < excluded.length; i++) {
			if (excludedBalances[i] > 0)
				_mint(excluded[i], excludedBalances[i], false);
		}
	}
}
