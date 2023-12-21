// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.18;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IBurnRedeemable} from "./interfaces/IBurnRedeemable.sol";
import {IAuction} from "./interfaces/IAuction.sol";
import {IXNF} from "./interfaces/IXNF.sol";

/*
 * @title XNF Contract
 *
 * @notice XNF is an ERC20 token with enhanced features such as token locking and specialized minting
 * and burning mechanisms. It's primarily used within a broader protocol to reward users who burn YSL or vXEN.
 *
 * Co-Founders:
 * - Simran Dhillon: simran@xenify.io
 * - Hardev Dhillon: hardev@xenify.io
 * - Dayana Plaz: dayana@xenify.io
 *
 * Official Links:
 * - Twitter: https://twitter.com/xenify_io
 * - Telegram: https://t.me/xenify_io
 * - Website: https://xenify.io
 *
 * Disclaimer:
 * This contract aligns with the principles of the Fair Crypto Foundation, promoting self-custody, transparency, consensus-based
 * trust, and permissionless value exchange. There are no administrative access keys, underscoring our commitment to decentralization.
 * Engaging with this contract involves technical and legal risks. Users must conduct their own due diligence and ensure compliance
 * with local laws and regulations. The software is provided "AS-IS," without warranties, and the co-founders and developers disclaim
 * all liability for any vulnerabilities, exploits, errors, or breaches that may occur. By using this contract, users accept all associated
 * risks and this disclaimer. The co-founders, developers, or related parties will not bear liability for any consequences of non-compliance.
 *
 * Redistribution and Use:
 * Redistribution, modification, or repurposing of this contract, in whole or in part, is strictly prohibited without express written
 * approval from all co-founders. Approval requests must be sent to the official email addresses of the co-founders, ensuring responses
 * are received directly from these addresses. Proposals for redistribution, modification, or repurposing must include a detailed explanation
 * of the intended changes or uses and the reasons behind them. The co-founders reserve the right to request additional information or
 * clarification as necessary. Approval is at the sole discretion of the co-founders and may be subject to conditions to uphold the
 * project’s integrity and the values of the Fair Crypto Foundation. Failure to obtain express written approval prior to any redistribution,
 * modification, or repurposing will result in a breach of these terms and immediate legal action.
 *
 * Copyright and License:
 * Copyright © 2023 Xenify (Simran Dhillon, Hardev Dhillon, Dayana Plaz). All rights reserved.
 * This software is provided 'as is' and may be used by the recipient. No permission is granted for redistribution,
 * modification, or repurposing of this contract. Any use beyond the scope defined herein may be subject to legal action.
 */
contract XNF is
    IXNF,
    ERC20
{

    /// ------------------------------------ VARIABLES ------------------------------------- \\\

    /**
     * @notice Address of the Auction contract, set during deployment and cannot be changed.
     */
    address public Auction;

    /**
     * @notice Address of the Recycle contract, set during deployment and cannot be changed.
     */
    address public Recycle;

    /**
     * @notice Address of the protocol owned liquidity pool contract, set after initialising the pool and cannot be changed.
     */
    address public lpAddress;

    /**
     * @notice Root of the Merkle tree used for airdrop claims.
     */
    bytes32 public merkleRoot;

    /**
     * @notice Duration (in days) for which tokens are locked. Set to 730 days (2 years).
     */
    uint256 public lockPeriod;

    /**
     * @notice Timestamp when the contract was initialised, set during deployment and cannot be changed.
     */
    uint256 public i_timestamp;

    /// ------------------------------------ MAPPINGS --------------------------------------- \\\

    /**
     * @notice Keeps track of token lock details for each user.
     */
    mapping (address => Lock) public userLocks;

    /**
     * @notice Records the total number of tokens burned by each user.
     */
    mapping (address => uint256) public userBurns;

    /**
     * @notice Mapping to track if a user has claimed their airdrop.
     */
    mapping (bytes32 => bool) public airdropClaimed;

    /// ------------------------------------ CONSTRUCTOR ------------------------------------ \\\

    /**
     * @notice Initialises the XNF token with a specified storage contract address, sets the token's name and symbol.
     */
    constructor()
        payable
        ERC20("XNF", "XNF")
    {}

    /// --------------------------------- EXTERNAL FUNCTIONS -------------------------------- \\\

    /**
     * @notice Initialises the contract with Auction contract's address and merkleRoot.
     * @dev Fails if the contract has already been initialised i.e., address of Auction is zero.
     * @param _auction Address of the Auction contract.
     * @param _merkleRoot Hashed Root of Merkle Tree for Airdrop.
     */
    function initialise(
        address _auction,
        address _recycle,
        bytes32 _merkleRoot
    ) external {
        if (Auction != address(0))
            revert ContractInitialised(Auction);
        lockPeriod = 730;
        Auction = _auction;
        Recycle = _recycle;
        merkleRoot = _merkleRoot;
        i_timestamp = block.timestamp;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Sets the liquidity pool (LP) address.
     * @dev Only the Auction contract is allowed to call this function.
     * @param _lp The address of the liquidity pool to be set.
     */
    function setLPAddress(address _lp)
        external
        override
    {
        if (msg.sender != Auction) {
            revert OnlyAuctionAllowed();
        }
        lpAddress = _lp;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows users to claim their airdropped tokens using a Merkle proof.
     * @dev Verifies the Merkle proof against the stored Merkle root and mints the claimed amount to the user.
     * @param proof Array of bytes32 values representing the Merkle proof.
     * @param account Address of the user claiming the airdrop.
     * @param amount Amount of tokens being claimed.
     */
    function claim(
        bytes32[] calldata proof,
        address account,
        uint256 amount
    )
        external
        override
    {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert InvalidClaimProof();
        }
        if (airdropClaimed[leaf]) {
            revert AirdropAlreadyClaimed();
        }
        if (i_timestamp + 2 hours > block.timestamp ) {
            revert TooEarlyToClaim();
        }
        airdropClaimed[leaf] = true;
        _mint(account, amount);
        unchecked {
            userLocks[account] = Lock(
                amount,
                block.timestamp,
                uint128((amount * 1e18) / lockPeriod),
                0
            );
        }
        emit Airdropped(account, amount);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Mints XNF tokens to a specified account.
     * @dev Only the Auction contract can mint tokens, and the total supply cap is checked before minting.
     * @param account Address receiving the minted tokens.
     * @param amount Number of tokens to mint.
     */
    function mint(
        address account,
        uint256 amount
    )
        external
        override
    {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        if (msg.sender != Auction) {
            revert OnlyAuctionAllowed();
        }
        if (totalSupply() + amount >= 22_600_000 ether) {
            revert ExceedsMaxSupply();
        }
        _mint(account, amount);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns a specified amount of tokens from a user's account.
     * @dev The calling contract must support the IBurnRedeemable interface.
     * @param user Address from which tokens will be burned.
     * @param amount Number of tokens to burn.
     */
    function burn(
        address user,
        uint256 amount
    )
        external
        override
    {
        if (!IERC165(msg.sender).supportsInterface(type(IBurnRedeemable).interfaceId)) {
            revert UnsupportedInterface();
        }
        if (msg.sender != user) {
            _spendAllowance(user, msg.sender, amount);
        }
        _burn(user, amount);
        unchecked{
            userBurns[user] += amount;
        }
        IBurnRedeemable(msg.sender).onTokenBurned(user, amount);
    }

    /// --------------------------------- PUBLIC FUNCTIONS ---------------------------------- \\\

    /**
     * @notice Determines the number of days since a user's tokens were locked.
     * @dev If the elapsed days exceed the lock period, it returns the lock period.
     * @param _user Address of the user to check.
     * @return passedDays Number of days since the user's tokens were locked, capped at the lock period.
     */
    function daysPassed(address _user)
        public
        override
        view
        returns (uint256 passedDays)
    {
        passedDays = (block.timestamp - userLocks[_user].timestamp) / 1 days;
        if (passedDays > lockPeriod) {
            passedDays = lockPeriod;
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Computes the amount of unlocked tokens for a user based on the elapsed time since locking.
     * @dev If the user's tokens have been locked for the full lock period, all tokens are considered unlocked.
     * @param _user Address of the user to check.
     * @return unlockedTokens Number of tokens that are currently unlocked for the user.
     */
    function getUnlockedTokensAmount(address _user)
        public
        override
        view
        returns (uint256 unlockedTokens)
    {
        uint256 passedDays = daysPassed(_user);
        Lock storage lock = userLocks[_user];
        if (userLocks[_user].timestamp != 0) {
            if (passedDays >= lockPeriod) {
                unlockedTokens = lock.amount;
            } else {
                unchecked {
                    unlockedTokens = (passedDays * lock.dailyUnlockAmount) / 1e18;
                }
            }
        }
    }

    /// -------------------------------- INTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Manages token transfers, ensuring that locked tokens are not transferred.
     * @dev This hook is invoked before any token transfer. It checks the locking conditions and updates lock details.
     * @param from Address sending the tokens.
     * @param amount Number of tokens being transferred.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override
    {
        if (userLocks[from].timestamp != 0) {
            Lock storage lock = userLocks[from];
            uint256 passedDays = daysPassed(from);
            uint256 unlockedTokens = getUnlockedTokensAmount(from);
            uint256 userBalance = balanceOf(from);
            if (passedDays >= lockPeriod) {
                lock.timestamp = 0;
            }
            if (amount > userBalance - (lock.amount - unlockedTokens)) {
                revert InsufficientUnlockedTokens();
            }
            uint256 userUsedAmount = userLocks[from].usedAmount;
            unchecked {
                uint256 notLockedTokens = userBalance + userUsedAmount - userLocks[from].amount;
                if (amount > notLockedTokens) {
                    userLocks[from].usedAmount = uint128(userUsedAmount + amount - notLockedTokens);
                }
            }
        }
        if (lpAddress != address(0) && from == lpAddress && to != Recycle) {
            revert CantPurchaseFromPOL();
        }
        if (lpAddress != address(0) && to == lpAddress && from != Recycle && from != Auction) {
            revert CanSellOnlyViaRecycle();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\
}