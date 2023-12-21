pragma solidity ^0.6.0;

// WARNING: Should be deployed only in Matic

import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import {IChildToken} from "./Matic/IChildToken.sol";
import {NetworkAgnostic} from "./Matic/NetworkAgnostic.sol";
import {ChainConstants} from "./Matic/ChainConstants.sol";

/**
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to aother accounts
 */
contract ChainTokenMatic is Initializable, ContextUpgradeSafe, AccessControlUpgradeSafe, ERC20BurnableUpgradeSafe, ERC20PausableUpgradeSafe, IChildToken, NetworkAgnostic, ChainConstants {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC20-constructor}.
     */

    function initialize(string memory name, string memory symbol, uint8 decimals, uint256 totalSupply) public {
        __ChainToken_init(name, symbol, decimals, totalSupply);
    }

    function __ChainToken_init(string memory name, string memory symbol, uint8 decimals, uint256 totalSupply) initializer internal {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __ChainToken_init_unchained();
        __NetworkAgnostic_init_unchained(name, ERC712_VERSION, CHILD_CHAIN_ID);
        _mint(_msgSender(), totalSupply * (10 ** uint256(decimals)));
    }

    function __ChainToken_init_unchained() initializer internal {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, _msgSender());
    }

    modifier only(bytes32 role) {
        require(hasRole(role, _msgSender()), "ChainToken: Insufficient Permissions");
        _;
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() only(PAUSER_ROLE) public {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() only(PAUSER_ROLE) public {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20UpgradeSafe, ERC20PausableUpgradeSafe) 
    notBlacklisted(to)
    notBlacklisted(from)
    {
        require(to != address(this), "ChainToken: can't transfer to contract address itself");
        super._beforeTokenTransfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount)
    internal 
    override(ERC20UpgradeSafe)
    notBlacklisted(owner)
    notBlacklisted(spender)
    {
        super._approve(owner, spender, amount);
    }

    function withdrawTokens(address tokenContract) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ChainToken [withdrawTokens]: must have admin role to withdraw");
        IERC20 tc = IERC20(tokenContract);
        require(tc.transfer(_msgSender(), tc.balanceOf(address(this))), "ChainToken [withdrawTokens] Something went wrong while transferring");
    }

    function version() public pure returns (string memory) {
        return "v2";
    }

    /*
     * Matic specific functions
     */

    function _msgSender()
        internal
        override
        view
        returns (address payable sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = msg.sender;
        }
        return sender;
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */
    function deposit(address user, bytes calldata depositData)
        external
        override
        only(DEPOSITOR_ROLE)
    {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    //BlackListing
    mapping(address => bool) internal blacklisted;
    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);

    /**
     * @dev Throws if argument account is blacklisted
     * @param _account The address to check
    */
    modifier notBlacklisted(address _account) {
        require(blacklisted[_account] == false);
        _;
    }

    /**
     * @dev Checks if account is blacklisted
     * @param _account The address to check    
    */
    function isBlacklisted(address _account) public view returns (bool) {
        return blacklisted[_account];
    }

    /**
     * @dev Adds account to blacklist
     * @param _account The address to blacklist
    */
    function blacklist(address _account) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ChainToken [blacklist]: must have admin role to blacklist");
        blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    /**
     * @dev Removes account from blacklist
     * @param _account The address to remove from the blacklist
    */
    function unBlacklist(address _account) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ChainToken [unBlacklist]: must have admin role to unBlacklist");
        blacklisted[_account] = false;
        emit UnBlacklisted(_account);
    }
}
