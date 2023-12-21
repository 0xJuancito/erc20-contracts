// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";

/**
 * @title Mountain Protocol USD Contract
 * @custom:security-contact security@mountainprotocol.com
 */
contract USDM is
    IERC20MetadataUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IERC20PermitUpgradeable,
    EIP712Upgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Token name
    string private _name;
    // Token Symbol
    string private _symbol;
    // Total token shares
    uint256 private _totalShares;
    // Base value for rewardMultiplier
    uint256 private constant _BASE = 1e18;
    /**
     * @dev rewardMultiplier represents a coefficient used in reward calculation logic.
     * The value is represented with 18 decimal places for precision.
     */
    uint256 public rewardMultiplier;

    // Mapping of shares per address
    mapping(address => uint256) private _shares;
    // Mapping of block status per address
    mapping(address => bool) private _blocklist;
    // Mapping of allowances per owner and spender
    mapping(address => mapping(address => uint256)) private _allowances;
    // Mapping of nonces per address
    mapping(address => CountersUpgradeable.Counter) private _nonces;

    // Permit typehash constant
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // Access control roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant BLOCKLIST_ROLE = keccak256("BLOCKLIST_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    // Events
    event AccountBlocked(address indexed addr);
    event AccountUnblocked(address indexed addr);
    event RewardMultiplier(uint256 indexed value);

    /**
     * Standard ERC20 Errors
     * @dev See https://eips.ethereum.org/EIPS/eip-6093
     */
    error ERC20InsufficientBalance(address sender, uint256 shares, uint256 sharesNeeded);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
    // ERC2612 Errors
    error ERC2612ExpiredDeadline(uint256 deadline, uint256 blockTimestamp);
    error ERC2612InvalidSignature(address owner, address spender);
    // USDM Errors
    error USDMInvalidMintReceiver(address receiver);
    error USDMInvalidBurnSender(address sender);
    error USDMInsufficientBurnBalance(address sender, uint256 shares, uint256 sharesNeeded);
    error USDMInvalidRewardMultiplier(uint256 rewardMultiplier);
    error USDMBlockedSender(address sender);
    error USDMInvalidBlockedAccount(address account);
    error USDMPausedTransfers();

    /**
     * @notice Initializes the contract.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param owner Owner address.
     */
    function initialize(string memory name_, string memory symbol_, address owner) external initializer {
        _name = name_;
        _symbol = symbol_;
        _setRewardMultiplier(_BASE);

        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __EIP712_init(name_, "1");

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Ensures that only accounts with UPGRADE_ROLE can upgrade the contract.
     */
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADE_ROLE) {}

    /**
     * @notice Returns the name of the token.
     * @return A string representing the token's name.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token.
     * @return A string representing the token's symbol.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the number of decimals the token uses.
     * @dev This value is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including.
     * {IERC20-balanceOf} and {IERC20-transfer}.
     * @return The number of decimals (18)
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Converts an amount of tokens to shares.
     * @param amount The amount of tokens to convert.
     * @return The equivalent amount of shares.
     *
     * Note: All rounding errors should be rounded down in the interest of the protocol's safety.
     * Token transfers, including mint and burn operations, may require a rounding, leading to potential
     * transferring at most one GWEI less than expected aggregated over a long period of time.
     */
    function convertToShares(uint256 amount) public view returns (uint256) {
        return (amount * _BASE) / rewardMultiplier;
    }

    /**
     * @notice Converts an amount of shares to tokens.
     * @param shares The amount of shares to convert.
     * @return The equivalent amount of tokens.
     */
    function convertToTokens(uint256 shares) public view returns (uint256) {
        return (shares * rewardMultiplier) / _BASE;
    }

    /**
     * @notice Returns the total amount of shares.
     * @return The total amount of shares.
     */
    function totalShares() external view returns (uint256) {
        return _totalShares;
    }

    /**
     * @notice Returns the total supply of tokens.
     * @return The total supply of tokens.
     */
    function totalSupply() external view returns (uint256) {
        return convertToTokens(_totalShares);
    }

    /**
     * @notice Returns the amount of shares owned by the account.
     * @param account The account to check.
     * @return The amount of shares owned by the account.
     */
    function sharesOf(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @notice Returns the balance of the specified address.
     * @dev Balances are dynamic and equal the `account`'s share in the amount of the
     * total reserves controlled by the protocol. See `sharesOf`.
     * @param account The address to query the balance of.
     * @return The balance of the specified address.
     */
    function balanceOf(address account) external view returns (uint256) {
        return convertToTokens(sharesOf(account));
    }

    /**
     * @dev Private function that mints a specified number of tokens to the given address.
     * Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - Only users with MINTER_ROLE can call this function.
     * - `account` cannot be the zero address.
     * @param to The address to which tokens will be minted.
     * @param amount The number of tokens to mint.
     *
     * Note: This function does not prevent minting to blocked accounts for gas efficiency.
     * It is the caller's responsibility to ensure that blocked accounts are not provided as `to`.
     */
    function _mint(address to, uint256 amount) private {
        if (to == address(0)) {
            revert USDMInvalidMintReceiver(to);
        }

        _beforeTokenTransfer(address(0), to, amount);

        uint256 shares = convertToShares(amount);
        _totalShares += shares;

        unchecked {
            // Overflow not possible: shares + shares amount is at most totalShares + shares amount
            // which is checked above.
            _shares[to] += shares;
        }

        _afterTokenTransfer(address(0), to, amount);
    }

    /**
     * @notice Creates new tokens to the specified address.
     * @dev See {_mint}.
     * @param to The address to mint the tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Private function that burns `amount` tokens from `account`, reducing the total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - Only users with BURNER_ROLE can call this function.
     * - The contract must not be paused.
     * @param account The address from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     *
     * Note: Tokens from a blocked account can not be burned.
     */
    function _burn(address account, uint256 amount) private {
        if (account == address(0)) {
            revert USDMInvalidBurnSender(account);
        }

        _beforeTokenTransfer(account, address(0), amount);

        uint256 shares = convertToShares(amount);
        uint256 accountShares = sharesOf(account);

        if (accountShares < shares) {
            revert USDMInsufficientBurnBalance(account, accountShares, shares);
        }

        unchecked {
            _shares[account] = accountShares - shares;
            // Overflow not possible: amount <= accountShares <= totalShares.
            _totalShares -= shares;
        }

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @notice Destroys a specified amount of tokens from the given address.
     * @dev See {_burn}.
     * @param from The address from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @dev Private function of a hook that is called before any transfer of tokens. This includes
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
     * Note: If either `from` or `to` are blocked, or the contract is paused, it reverts the transaction.
     */
    function _beforeTokenTransfer(address from, address /* to */, uint256 /* amount */) private view {
        // Each blocklist check is an SLOAD, which is gas intensive.
        // We only block sender not receiver, so we don't tax every user
        if (isBlocked(from)) {
            revert USDMBlockedSender(from);
        }
        // Useful for scenarios such as preventing trades until the end of an evaluation
        // period, or having an emergency switch for freezing all token transfers in the
        // event of a large bug.
        if (paused()) {
            revert USDMPausedTransfers();
        }
    }

    /**
     * @dev Private funciton of a hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) private {
        emit Transfer(from, to, amount);
    }

    /**
     * @dev Private function that transfers a specified number of tokens from one address to another.
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     * @param from The address from which tokens will be transferred.
     * @param to The address to which tokens will be transferred.
     * @param amount The number of tokens to transfer.
     *
     * Note: This function does not prevent transfers to blocked accounts for gas efficiency.
     * As such, users should be aware of who they're transacting with.
     * Sending tokens to a blocked account could result in those tokens becoming inaccessible.
     */
    function _transfer(address from, address to, uint256 amount) private {
        if (from == address(0)) {
            revert ERC20InvalidSender(from);
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(to);
        }

        _beforeTokenTransfer(from, to, amount);

        uint256 shares = convertToShares(amount);
        uint256 fromShares = _shares[from];

        if (fromShares < shares) {
            revert ERC20InsufficientBalance(from, fromShares, shares);
        }

        unchecked {
            _shares[from] = fromShares - shares;
            // Overflow not possible: the sum of all shares is capped by totalShares, and the sum is preserved by
            // decrementing then incrementing.
            _shares[to] += shares;
        }

        _afterTokenTransfer(from, to, amount);
    }

    /**
     * @notice Transfers a specified number of tokens from the caller's address to the recipient.
     * @dev See {_transfer}.
     * @param to The address to which tokens will be transferred.
     * @param amount The number of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        address owner = _msgSender();

        _transfer(owner, to, amount);

        return true;
    }

    /**
     * @dev Private function that blocklists the specified address.
     * @param account The address to blocklist.
     *
     * Note: This function does not perform any checks against the zero address for gas efficiency.
     * It is the caller's responsibility to ensure that the zero address is not provided as `account`.
     * Blocking the zero address could have unintended effects on token minting and burning.
     */
    function _blockAccount(address account) private {
        if (isBlocked(account)) {
            revert USDMInvalidBlockedAccount(account);
        }

        _blocklist[account] = true;
        emit AccountBlocked(account);
    }

    /**
     * @dev Private function that removes the specified address from the blocklist.
     * @param account The address to remove from the blocklist.
     */
    function _unblockAccount(address account) private {
        if (!isBlocked(account)) {
            revert USDMInvalidBlockedAccount(account);
        }

        _blocklist[account] = false;
        emit AccountUnblocked(account);
    }

    /**
     * @notice Blocks multiple accounts at once.
     * @dev This function can only be called by an account with BLOCKLIST_ROLE.
     * @param addresses An array of addresses to be blocked.
     */
    function blockAccounts(address[] calldata addresses) external onlyRole(BLOCKLIST_ROLE) {
        for (uint256 i = 0; i < addresses.length; i++) {
            _blockAccount(addresses[i]);
        }
    }

    /**
     * @notice Removes multiple accounts from the blocklist at once.
     * @dev This function can only be called by an account with BLOCKLIST_ROLE.
     * @param addresses An array of addresses to be removed from the blocklist.
     */
    function unblockAccounts(address[] calldata addresses) external onlyRole(BLOCKLIST_ROLE) {
        for (uint256 i = 0; i < addresses.length; i++) {
            _unblockAccount(addresses[i]);
        }
    }

    /**
     * @notice Checks if the specified address is blocked.
     * @param account The address to check.
     * @return A boolean value indicating whether the address is blocked.
     */
    function isBlocked(address account) public view returns (bool) {
        return _blocklist[account];
    }

    /**
     * @notice Pauses token transfers and other operations.
     * @dev This function can only be called by an account with PAUSE_ROLE.
     * @dev Inherits the _pause function from @openzeppelin/PausableUpgradeable contract.
     */
    function pause() external onlyRole(PAUSE_ROLE) {
        super._pause();
    }

    /**
     * @notice Unpauses token transfers and other operations.
     * @dev This function can only be called by an account with PAUSE_ROLE.
     * @dev Inherits the _unpause function from @openzeppelin/PausableUpgradeable contract.
     */
    function unpause() external onlyRole(PAUSE_ROLE) {
        super._unpause();
    }

    /**
     * @dev Private function to set the reward multiplier.
     * @param _rewardMultiplier The new reward multiplier.
     */
    function _setRewardMultiplier(uint256 _rewardMultiplier) private {
        if (_rewardMultiplier < _BASE) {
            revert USDMInvalidRewardMultiplier(_rewardMultiplier);
        }

        rewardMultiplier = _rewardMultiplier;

        emit RewardMultiplier(rewardMultiplier);
    }

    /**
     * @notice Sets the reward multiplier.
     * @dev This function can only be called by DEFAULT_ADMIN_ROLE.
     * @param _rewardMultiplier The new reward multiplier.
     */
    function setRewardMultiplier(uint256 _rewardMultiplier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRewardMultiplier(_rewardMultiplier);
    }

    /**
     * @notice Adds the given amount to the current reward multiplier.
     * @dev This function can only be called by an account with ORACLE_ROLE.
     * @param _rewardMultiplierIncrement The amount to add to the current reward multiplier
     */
    function addRewardMultiplier(uint256 _rewardMultiplierIncrement) external onlyRole(ORACLE_ROLE) {
        if (_rewardMultiplierIncrement == 0) {
            revert USDMInvalidRewardMultiplier(_rewardMultiplierIncrement);
        }

        _setRewardMultiplier(rewardMultiplier + _rewardMultiplierIncrement);
    }

    /**
     * @dev Private function to set `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Note: This function does not prevent blocked accounts to approve allowance for gas efficiency.
     * It is the caller's responsibility to ensure that blocked accounts are not provided.
     */
    function _approve(address owner, address spender, uint256 amount) private {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(owner);
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(spender);
        }

        _allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    /**
     * @notice Approves an allowance for a spender.
     * @dev See {IERC20-approve}.
     *
     * Note: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        address owner = _msgSender();

        _approve(owner, spender, amount);

        return true;
    }

    /**
     * @notice Returns the remaining amount of tokens that `spender` is allowed to spend on behalf of `owner`.
     * @dev See {IERC20-allowance}.
     * @param owner The address of the token owner.
     * @param spender The address of the spender.
     * @return The remaining allowance of the spender on behalf of the owner.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Private function that updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) private {
        uint256 currentAllowance = allowance(owner, spender);

        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            }

            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @notice Moves tokens from an address to another one using the allowance mechanism.
     * @dev See {IERC20-transferFrom}.
     *
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. This allows applications to reconstruct the allowance
     * for all accounts just by listening to said events.
     *
     * Note: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least `amount`.
     * @param from The address from which tokens will be transferred.
     * @param to The address to which tokens will be transferred.
     * @param amount The number of tokens to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        address spender = _msgSender();

        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);

        return true;
    }

    /**
     * @notice Increases the allowance granted to spender by the caller.
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
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        address owner = _msgSender();

        _approve(owner, spender, allowance(owner, spender) + addedValue);

        return true;
    }

    /**
     * @notice Decreases the allowance granted to spender by the caller.
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
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);

        if (currentAllowance < subtractedValue) {
            revert ERC20InsufficientAllowance(spender, currentAllowance, subtractedValue);
        }

        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @notice Returns the EIP-712 DOMAIN_SEPARATOR.
     * @return A bytes32 value representing the EIP-712 DOMAIN_SEPARATOR.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Returns the current nonce for the given owner address.
     * @param owner The address whose nonce is to be retrieved.
     * @return The current nonce as a uint256 value.
     */
    function nonces(address owner) external view returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev Private function that increments and returns the current nonce for a given owner address.
     * @param owner The address whose nonce is to be incremented.
     */
    function _useNonce(address owner) private returns (uint256 current) {
        CountersUpgradeable.Counter storage nonce = _nonces[owner];
        current = nonce.current();

        nonce.increment();
    }

    /**
     * @notice Allows an owner to approve a spender with a one-time signature, bypassing the need for a transaction.
     * @dev Uses the EIP-2612 standard.
     * @param owner The address of the token owner.
     * @param spender The address of the spender.
     * @param value The amount of tokens to be approved.
     * @param deadline The expiration time of the signature, specified as a Unix timestamp.
     * @param v The recovery byte of the signature.
     * @param r The first 32 bytes of the signature.
     * @param s The second 32 bytes of the signature.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredDeadline(deadline, block.timestamp);
        }

        bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSAUpgradeable.recover(hash, v, r, s);

        if (signer != owner) {
            revert ERC2612InvalidSignature(owner, spender);
        }

        _approve(owner, spender, value);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[42] private __gap;
}
