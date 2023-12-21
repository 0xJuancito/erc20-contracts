pragma solidity ^0.8.15;

import "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "openzeppelin/metatx/ERC2771Context.sol";

/**
 * This contract represents an ERC20 token backed by the Num Finance platform.
 *
 * The main functionalities included in this implementation are:
 *   - ERC2771 support, for gasless transactions
 *   - a disallow-list implementation: which disables transfers for disallowed accounts
 *   - a circuit breaker that can pause and resume token withdrawals
 *
 * Additionally, this contract overrides functions found both in ContextUpgradeable and ERC2771Context
 * in order to resolve name collisions, defaulting to the ERC2771 compliant implementation.
 */
contract NumToken is ERC20Upgradeable, AccessControlUpgradeable, ERC2771Context {
    /**
     * @dev ERC2771 / ContextUpgradeable override function. Defaults to ERC2771 behaviour.
     */
    function _msgSender() internal view virtual override(ContextUpgradeable, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev ERC2771 / ContextUpgradeable override function. Defaults to ERC2771 behaviour.
     */
    function _msgData() internal view virtual override(ContextUpgradeable, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @dev ERC2771Context-aware onlyRole modifier. The one provided by AccessControlUpgradeable uses msg.sender instead of _msgSender().
     */
    modifier only2771Role(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @notice Role in charge of minting and burning tokens.
     */
    bytes32 public constant MINTER_BURNER_ROLE = keccak256("MINTER_BURNER_ROLE");

    /* Disallow list control */

    /**
     * @notice Role in charge of managing disallowlist entries.
     */
    bytes32 public constant DISALLOW_ROLE = keccak256("DISALLOW_ROLE");

    mapping(address => bool) private _disallowed;

    /// @notice Emitted whenever an account is disallowed.
    event Disallowed(address indexed account);

    /// @notice Emitted whenever an account is re-allowed.
    event Allowed(address indexed account);

    /* Circuit breaker */

    /**
     * @notice Role in charge of pulling the circuit breaker.
     */
    bytes32 public constant CIRCUIT_BREAKER_ROLE = keccak256("CIRCUIT_BREAKER_ROLE");

    bool public paused = false;

    /// @notice Emitted when the circuit breaker is either tripped or reset.
    event PauseStateChanged(bool indexed paused);

    constructor(address forwarder_) ERC2771Context(forwarder_) {}
    

    /**
     * @notice Initialization function.
     * @dev As per Initializable::initialize this function can only be called once.
     * @param name_ The name the token should have.
     * @param symbol_ The symbol the token should have.
     */
    function initialize(string memory name_, string memory symbol_) public initializer {
        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }


    /* Mint/Burn */

    /**
     * @notice Mints {amount} tokens to {account}.
     * @dev This function can only be called by members of {MINTER_BURNER_ROLE}. Falls back to ERC20Upgradeable::_mint
     * @param account Address to mint to.
     * @param amount Amount of tokens to mint.
     */
    function mint(address account, uint256 amount) public only2771Role(MINTER_BURNER_ROLE) {
        _mint(account, amount);
    }

    /**
     * @notice Burns {amount} tokens from {account}.
     * @dev Can only be called by members of {MINTER_BURNER_ROLE}. Falls back to ERC20Upgradeable::_burn
     * @param account Address to burn tokens from.
     * @param amount Amount of tokens to burn.
     */
    function burn(address account, uint256 amount) public only2771Role(MINTER_BURNER_ROLE) {
        _burn(account, amount);
    }

    /**
     * @notice Transfers {amount} tokens from {sender} to {recipient}
     * @dev ERC20 _transfer override. Implements the circuit-breaker functionality.
     * @param sender Address from which tokens will be taken.
     * @param recipient Address to which tokens will be moved.
     * @param amount Amount of tokens to transfer.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        /**
          Disallow transfers whenever the circuit breaker is pulled.
          This check is done here since we have to allow mint() and burn()
          calls while in this state, to enable clawback of funds if they are stolen.
        */
        require(!paused, "NumToken: transfers paused");

        super._transfer(sender, recipient, amount);
    }

    /* Disallow list management */

    /**
     * @notice Disallows {account} from sending/receiving tokens. Only callable by members of {DISALLOW_ROLE}
     * @param account Address to disallow.
     */
    function disallow(address account) public only2771Role(DISALLOW_ROLE) {
        _disallowed[account] = true;
        emit Disallowed(account);
    }

    /**
     * @notice Re-allows {account} to send or receive tokens. Only callable by members of {DISALLOW_ROLE}
     * @param account Address to allow.
     */
    function allow(address account) public only2771Role(DISALLOW_ROLE) {
        _disallowed[account] = false;
        emit Allowed(account);
    }

    /**
     * @notice Returns whether an account is disallowed.
     * @param account Address to check.
     */
    function isDisallowed(address account) public view returns (bool) {
        return _disallowed[account];
    }

    /**
     * @dev ERC20Upgradeable hook override. Checks whether {from} and {to} are allowed to send/receive tokens.
     * @param from Sender account
     * @param to Recipient account
     * @param amount Amount of tokens being transferred.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        /* Disallow transfers to and from disallowed accounts */
        require(!_disallowed[from] && ! _disallowed[to], "NumToken: Disallowed account");
    }

    /**
     * @notice Toggles the circuit breaker, pausing or unpausing the contract.
     * @dev only callable by members of {CIRCUIT_BREAKER_ROLE}
     */
    function togglePause() public only2771Role(CIRCUIT_BREAKER_ROLE) {
        paused = !paused;
        emit PauseStateChanged(paused);
    }
}

