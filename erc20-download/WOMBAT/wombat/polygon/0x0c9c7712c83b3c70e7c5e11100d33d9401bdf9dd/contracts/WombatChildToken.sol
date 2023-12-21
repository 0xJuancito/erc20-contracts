// SPDX-License-Identifier: UNLICENSED
import "../openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "../openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "../openzeppelin-contracts/contracts/access/AccessControl.sol";
pragma solidity 0.8.5;

/**
 * @title WombatChildToken
 * @dev An ERC20 token to be used as a child token for the Polygon PoS bridge.
 * It allows minting tokens via a "deposit" function that can be called by the Polygon bridge
 * chain manager proxy
 * See https://docs.polygon.technology/docs/develop/ethereum-polygon/pos/mapping-assets#custom-child-token
 */
contract WombatChildToken is ERC20Burnable, ERC20Pausable, ERC20Capped, AccessControl {

    /**
     * @dev The depositor can mint tokens using the "deposit" function.
     */
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR");

    /**
     * @dev The pauser can pause token transfers.
     */
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER");

    /**
     * @dev Calls the {ERC20} constructor and sets up the roles.
     * @param name Name of the token (human readable)
     * @param symbol Ticker of the token
     * @param childChainManagerProxy The address of the Polygon PoS Bridge Child Chain manager proxy
     *  This address will be granted the {DEPOSITOR_ROLE} and thus can mint new tokens.
     * @param admin An address to be granted the {DEFAULT_ADMIN_ROLE} and the {PAUSER_ROLE}.
     * @param maxSupply The maximum amount of tokens that can be minted
     */
    constructor(
        string memory name, string memory symbol, address childChainManagerProxy,
        address admin, uint256 maxSupply
    ) ERC20(name, symbol) ERC20Capped(maxSupply) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(PAUSER_ROLE, admin);
        _setupRole(DEPOSITOR_ROLE, childChainManagerProxy);
    }

    /**
     * @dev Needs to be overridden to select the correct base implementation to call (ERC20Pausable
     *  in this case)
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Pause token transfers
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Mints new tokens to the user, amount is parsed from the depositData.
     * This function is intended to be called by the Polygon PoS bridge and thus is only executable
     * by the {DEPOSITOR_ROLE}.
     */
    function deposit(address user, bytes calldata depositData) external onlyRole(DEPOSITOR_ROLE) {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
     * @dev Needs to be overridden to select the correct base implementation (ERC20Capped in this case)
     */
    function _mint(address account, uint256 amount) internal override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }

    /**
     * @dev Burns tokens owned by the message sender. This is used to initiate a transfer back from
     * Polygon to Ethereum. Further manual actions is required after doing so, but in general this
     * is expected to be called by the Polygon Bridge dApp which takes care of everything.
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}
