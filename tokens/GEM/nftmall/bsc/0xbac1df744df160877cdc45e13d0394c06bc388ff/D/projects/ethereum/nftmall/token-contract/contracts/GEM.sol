/*
     ______________
    /_  _ ___ _____\                    _   _ 
   /| \| | __|_   _|\    _ __    __ _  | | | |
  { | .` | _|  | |   }  | '  \  / _` | | | | |
   \|_|\_|_|   |_|  /   |_|_|_| \__,_| |_| |_|
     \            /
       \        /
         \    /
           💎

  https://nftmall.io
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Openzeppelin Contracts Version 4.0.0
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract GEM is AccessControl, ERC20, Pausable, ERC20Burnable, ERC20Snapshot, ERC20Permit {
    using SafeERC20 for IERC20;

    string public constant NAME = "NFTmall GEM Token";
    string public constant SYMBOL = "GEM";
    uint256 public constant MAX_TOTAL_SUPPLY = 20_000_000 * 1e18;

    bytes32 public constant WHITELISTED_MSG_SENDER_ROLE = keccak256("WHITELISTED_MSG_SENDER_ROLE");       // Can transfer his own and transferFrom somebody's approved token when paused
    bytes32 public constant WHITELISTED_FROM_ROLE = keccak256("WHITELISTED_FROM_ROLE");                   // Anyone approved can transfer tokens from addresses with this role when paused

    modifier onlyGovernance() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "!governance");
        _;
    }

    constructor (address _governance) ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
        _setupRole(DEFAULT_ADMIN_ROLE, _governance);   // DEFAULT_ADMIN_ROLE can grant other roles
        _setupRole(WHITELISTED_MSG_SENDER_ROLE, _governance);   // Allows manual transfers
        _setupRole(WHITELISTED_FROM_ROLE, _governance);         // Allows add liquidity to Uniswap
        _mint(_governance, MAX_TOTAL_SUPPLY);
    }

    /**
     * @notice Triggers stopped state.
     * Requirements:
     * - The contract must not be paused.
     */
    function pause() external onlyGovernance {
        _pause();
    }

    /**
     * @notice Returns to normal state.
     * Requirements:
     * - The contract must be paused.
     */
    function unpause() external onlyGovernance {
        _unpause();
    }

    /**
     * @notice Creates a new snapshot and returns its snapshot id.
     * @return id of created snapshot
     */
    function snapshot() external onlyGovernance returns(uint256) {
        return _snapshot();
    }

    /**
     * @dev This function is overridden in both ERC20 and ERC20Snapshot, so we need to specify execution order here.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);

        require(
            !paused() ||                                    // unpaused mode
            hasRole(WHITELISTED_MSG_SENDER_ROLE, _msgSender()) ||      // transfer initiated by whitelisted address (allow trusted parties to transfer where it is needed)
            hasRole(WHITELISTED_FROM_ROLE, from),                      // from is whitelisted (can be used to add liquidity on uniswap without bot's pump and dump)
            "transfers paused"
        );
    }
}
