// SPDX-License-Identifier: agpl-3.0
// OpenZeppelin Contracts (last updated v4.8.0) (vext/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/utils/Checkpoints.sol";

/**
 * @dev Extension of ERC20 to support Compound-like voting and delegation. This version is more generic than Compound's,
 * and supports vext supply up to 2^224^ - 1, while COMP is limited to 2^96^ - 1.
 *
 * NOTE: If exact COMP compatibility is required, use the {ERC20VotesComp} variant of this module.
 *
 * This extension keeps a history (checkpoints) of each account's vote power. Vote power can be delegated either
 * by calling the {delegate} function directly, or by providing a signature to be used with {delegateBySig}. Voting
 * power can be queried through the public accessors {getVotes} and {getPastVotes}.
 *
 * By default, vext balance does not account for voting power. This makes transfers cheaper. The downside is that it
 * requires users to delegate to themselves in order to activate checkpoints and have their voting power tracked.
 *
 * _Available since v4.2._
 */
abstract contract ERC20VotesUpgradeable is
    Initializable,
    IVotesUpgradeable,
    ERC20PermitUpgradeable
{
    function __ERC20Votes_init() internal onlyInitializing {}

    function __ERC20Votes_init_unchained() internal onlyInitializing {}

    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => address) private _delegates;
    mapping(address => Checkpoint[]) private _checkpoints;
    Checkpoint[] private _totalSupplyCheckpoints;

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(
        address account,
        uint32 pos
    ) public view virtual returns (Checkpoint memory) {
        return _checkpoints[account][pos];
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(
        address account
    ) public view virtual returns (uint32) {
        return SafeCastUpgradeable.toUint32(_checkpoints[account].length);
    }

    /**
     * @dev Get the address `account` is currently delegating to.
     */
    function delegates(
        address account
    ) public view virtual override returns (address) {
        return _delegates[account];
    }

    /**
     * @dev Gets the current votes balance for `account`
     */
    function getVotes(
        address account
    ) public view virtual override returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev Retrieve the number of votes for `account` at the end of `blockNumber`.
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastVotes(
        address account,
        uint256 blockNumber
    ) public view virtual override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }

    /**
     * @dev Retrieve the `totalSupply` at the end of `blockNumber`. Note, this value is the sum of all balances.
     * It is but NOT the sum of all the delegated votes!
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastTotalSupply(
        uint256 blockNumber
    ) public view virtual override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_totalSupplyCheckpoints, blockNumber);
    }

    /**
     * @dev Lookup a value in a list of (sorted) checkpoints.
     */
    function _checkpointsLookup(
        Checkpoint[] storage ckpts,
        uint256 blockNumber
    ) private view returns (uint256) {
        // We run a binary search to look for the earliest checkpoint taken after `blockNumber`.
        //
        // Initially we check if the block is recent to narrow the search range.
        // During the loop, the index of the wanted checkpoint remains in the range [low-1, high).
        // With each iteration, either `low` or `high` is moved towards the middle of the range to maintain the invariant.
        // - If the middle checkpoint is after `blockNumber`, we look in [low, mid)
        // - If the middle checkpoint is before or equal to `blockNumber`, we look in [mid+1, high)
        // Once we reach a single value (when low == high), we've found the right checkpoint at the index high-1, if not
        // out of bounds (in which case we're looking too far in the past and the result is 0).
        // Note that if the latest checkpoint available is exactly for `blockNumber`, we end up with an index that is
        // past the end of the array, so we technically don't find a checkpoint after `blockNumber`, but it works out
        // the same.
        uint256 length = ckpts.length;

        uint256 low = 0;
        uint256 high = length;

        if (length > 5) {
            uint256 mid = length - MathUpgradeable.sqrt(length);
            if (_unsafeAccess(ckpts, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        while (low < high) {
            uint256 mid = MathUpgradeable.average(low, high);
            if (_unsafeAccess(ckpts, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : _unsafeAccess(ckpts, high - 1).votes;
    }

    /**
     * @dev Gets the number of votes for the specified account at the specified block number.
     * @param account The account to get the votes for.
     * @param blockNumber The block number to get the votes at.
     * @return The number of votes for the specified account at the specified block number.
     * Requirements:
     * - The specified block number must be less than the current block number.
     */
    function _getProposalVotes(
        address account,
        uint256 blockNumber
    ) internal view returns (uint256) {
        Checkpoint[] storage ckpts = _checkpoints[account];

        require(
            blockNumber < block.number,
            "ERC20VotesUpgradeable: block not yet mined"
        );
        uint32 key = SafeCastUpgradeable.toUint32(blockNumber);

        uint256 len = ckpts.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - MathUpgradeable.sqrt(len);
            if (key < _unsafeAccess(ckpts, mid).fromBlock) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        uint256 pos;

        ckpts.length == 1 && ckpts[0].fromBlock > blockNumber
            ? pos = 0
            : pos = _lowerBinaryLookup(ckpts, key, low, high);

        return pos == 0 ? 0 : _unsafeAccess(ckpts, pos - 1).votes;
    }

    /**
     * @dev Performs an upper-bound binary search for the specified key in the specified checkpoint array.
     * @param self The checkpoint array to search.
     * @param key The key to search for.
     * @param low The lower index to search from.
     * @param high The higher index to search to.
     * @return The index of the upper-bound checkpoint for the specified key.
     */
    function _upperBinaryLookup(
        Checkpoint[] storage self,
        uint32 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = MathUpgradeable.average(low, high);
            if (_unsafeAccess(self, mid).fromBlock > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev Performs a lower-bound binary search for the specified key in the specified checkpoint array.
     * @param self The checkpoint array to search.
     * @param key The key to search for.
     * @param low The lower index to search from.
     * @param high The higher index to search to.
     * @return The index of the lower-bound checkpoint for the specified key.
     */
    function _lowerBinaryLookup(
        Checkpoint[] storage self,
        uint32 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = MathUpgradeable.average(low, high);
            if (_unsafeAccess(self, mid).fromBlock < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev Delegate votes from the sender to `delegatee`.
     */
    function delegate(address delegatee) public virtual override {
        _delegate(_msgSender(), delegatee);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        require(block.timestamp <= expiry, "ERC20Votes: signature expired");
        address signer = ECDSAUpgradeable.recover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry)
                )
            ),
            v,
            r,
            s
        );
        require(nonce == _useNonce(signer), "ERC20Votes: invalid nonce");
        _delegate(signer, delegatee);
    }

    /**
     * @dev Maximum vext supply. Defaults to `type(uint224).max` (2^224^ - 1).
     */
    function _maxSupply() internal view virtual returns (uint224) {
        return type(uint224).max;
    }

    /**
     * @dev Snapshots the totalSupply after it has been increased.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
        require(
            totalSupply() <= _maxSupply(),
            "ERC20Votes: total supply risks overflowing votes"
        );

        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
    }

    /**
     * @dev Snapshots the totalSupply after it has been decreased.
     */
    function _burn(address account, uint256 amount) internal virtual override {
        super._burn(account, amount);

        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, amount);
    }

    function afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        _afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Move voting power when vexts are transferred.
     *
     * Emits a {IVotes-DelegateVotesChanged} event.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);

        _moveVotingPower(delegates(from), delegates(to), amount);
    }

    /**
     * @dev Change delegation for `delegator` to `delegatee`.
     *
     * Emits events {IVotes-DelegateChanged} and {IVotes-DelegateVotesChanged}.
     */
    function _delegate(address delegator, address delegatee) internal virtual {
        address currentDelegate = delegates(delegator);
        uint256 delegatorBalance = balanceOf(delegator);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    /**
     * @dev Moves voting power from one address to another.
     * @param src The source address to move voting power from.
     * @param dst The destination address to move voting power to.
     * @param amount The amount of voting power to move.
     * Requirements:
     * - The `src` address must have enough voting power to move.
     * - `src` and `dst` cannot be the zero address.
     * Emits a `DelegateVotesChanged` event for each address whose voting power changes.
     */
    function _moveVotingPower(
        address src,
        address dst,
        uint256 amount
    ) private {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    _checkpoints[src],
                    _subtract,
                    amount
                );
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    _checkpoints[dst],
                    _add,
                    amount
                );
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    /**
     * @dev Writes a new checkpoint for the specified checkpoint array using the specified operation and delta.
     * @param ckpts The checkpoint array to write a new checkpoint to.
     * @param op The operation to perform on the old and delta values.
     * @param delta The amount to perform the operation on.
     * return The old and new voting weights for the checkpoint.
     */
    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;

        Checkpoint memory oldCkpt = pos == 0
            ? Checkpoint(0, 0)
            : _unsafeAccess(ckpts, pos - 1);

        oldWeight = oldCkpt.votes;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && oldCkpt.fromBlock == block.number) {
            _unsafeAccess(ckpts, pos - 1).votes = SafeCastUpgradeable.toUint224(
                newWeight
            );
        } else {
            ckpts.push(
                Checkpoint({
                    fromBlock: SafeCastUpgradeable.toUint32(block.number),
                    votes: SafeCastUpgradeable.toUint224(newWeight)
                })
            );
        }
    }

    /**
     * @dev Adds two numbers together.
     * @param a The first number to add.
     * @param b The second number to add.
     * @return The sum of `a` and `b`.
     */
    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Subtracts one number from another.
     * @param a The number to subtract from.
     * @param b The number to subtract.
     * @return The difference between `a` and `b`.
     */
    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Provides unsafe access to a checkpoint in the specified checkpoint array at the specified position.
     * @param ckpts The checkpoint array to access.
     * @param pos The position of the checkpoint to access.
     * return The checkpoint at the specified position.
     * Requirements:
     * - The position must be within the bounds of the checkpoint array.
     * - The checkpoint array must not be modified after this function is called.
     */
    function _unsafeAccess(
        Checkpoint[] storage ckpts,
        uint256 pos
    ) private pure returns (Checkpoint storage result) {
        assembly {
            mstore(0, ckpts.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
