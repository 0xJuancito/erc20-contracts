// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// Storage for a YAM token
contract TokenStorage {

    /**
     * @notice EIP-20 token name for this token
     */
    string public name;

    /**
     * @notice EIP-20 token symbol for this token
     */
    string public symbol;

    /**
     * @notice EIP-20 token decimals for this token
     */
    uint8 public decimals;

    /**
     * @notice Whether transfers are paused
     */
    bool public transferPaused;

    /**
     * @notice Whether transfers are paused
     */
    bool public mintPaused;

    /**
     * @notice Whether transfers are paused
     */
    bool public burnPaused;

    /**
     * @notice Whether rebase are paused
     */
    bool public rebasePaused;

    /**
     * @notice Last proposal start period
     */
    uint32 public lastSnapshotTime;

    /**
     * @notice Decimal difference between shares and actual balance
     */
    uint256 public constant balanceToShareDecimals = 10**6;

    /**
     * @notice One share unit
     */
    uint256 public constant shareDecimals = 10**24;

    /**
     * @notice Map of token allowances
     */
    mapping (address => mapping (address => uint256)) internal _allowedBalances;

    /**
     * @notice The last timestamp that `syncSupply` was called
     * @dev Set to uint32 so balance calcs can use 1 sload
     */
    uint32 public syncStart;

    /**
     * @notice The end of the current reward distribution interval
     * @dev Set to uint32 so balance calcs can use 1 sload
     */
    uint32 public syncEnd;

    /**
     * @notice The `totalSupply` at `syncStart`
     * @dev Set to uint96 for balance calculations to use 1 ssload
     */
    uint96 public preSyncSupply;

    /**
     * @notice The amount of rewards to distribute over the interval
     * @dev Set to uint96 for balance calculations to use 1 ssload
     */
    uint96 public rewardsToSync;

    uint256[45] private __gap;
}