// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "IViciAccess.sol";
import "IOwnerOperator.sol";

/**
 * Information needed to mint a single token.
 */
struct ERC20MintData {
    address operator;
    bytes32 requiredRole;
    address toAddress;
    uint256 amount;
}

/**
 * Information needed to transfer a token.
 */
struct ERC20TransferData {
    address operator;
    address fromAddress;
    address toAddress;
    uint256 amount;
}

/**
 * Information needed to burn a token.
 */
struct ERC20BurnData {
    address operator;
    bytes32 requiredRole;
    address fromAddress;
    uint256 amount;
}

/**
 * @title ERC20 Operations Interface
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev Interface for ERC20 Operations.
 * @dev Main contracts SHOULD refer to the ops contract via the this interface.
 */
interface IERC20Operations is IOwnerOperator {
    /* ################################################################
     * Queries
     * ##############################################################*/

    /**
     * @dev Returns the total maximum possible that can be minted.
     */
    function getMaxSupply() external view returns (uint256);

    /**
     * @dev Returns the amount that has been minted so far.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev returns the amount available to be minted.
     * @dev {total available} = {max supply} - {amount minted so far}
     */
    function availableSupply() external view returns (uint256);

    /**
     * @dev see IERC20
     */
    function balanceOf(address account) external view returns (uint256 balance);

    /* ################################################################
     * Minting / Burning / Transferring
     * ##############################################################*/

    /**
     * @dev Safely mints a new token and transfers it to the specified address.
     * @dev Updates available quantities
     *
     * Requirements:
     *
     * - `mintData.operator` MUST be owner or have the required role.
     * - `mintData.operator` MUST NOT be banned.
     * - `mintData.toAddress` MUST NOT be 0x0.
     * - `mintData.toAddress` MUST NOT be banned.
     * - If `mintData.toAddress` refers to a smart contract, it must implement
     *      {IERC20Receiver-onERC20Received}, which is called upon a safe
     *      transfer.
     */
    function mint(IViciAccess ams, ERC20MintData memory mintData) external;

    /**
     * @dev see IERC20
     */
    function transfer(
        IViciAccess ams,
        ERC20TransferData memory transferData
    ) external;

    /**
     * @dev Burns the identified token.
     * @dev Updates available quantities
     *
     * Requirements:
     *
     * - `burnData.operator` MUST be owner or have the required role.
     * - `burnData.operator` MUST NOT be banned.
     * - `burnData.operator` MUST own the token or be authorized by the
     *     owner to transfer the token.
     */
    function burn(IViciAccess ams, ERC20BurnData memory burnData) external;

    /* ################################################################
     * Approvals / Allowances
     * ##############################################################*/

    /**
     * @dev see IERC20
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev See {IERC20Permit-permit}.
     */
    function permit(
        IViciAccess ams,
        address owner,
        address spender,
        uint256 amount
    ) external;

    /**
     * @notice recover assets in banned or sanctioned accounts
     *
     * Requirements
     * - `operator` MUST be the contract owner.
     * - `fromAddress` MUST be banned or OFAC sanctioned
     * - `toAddress` MAY be the zero address, in which case the
     *     assets are burned.
     * - `toAddress` MUST NOT be banned or OFAC sanctioned
     */
    function recoverSanctionedAssets(
        IViciAccess ams,
        address operator,
        address fromAddress,
        address toAddress
    ) external returns (uint256 amount);
}
