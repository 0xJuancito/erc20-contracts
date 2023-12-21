// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (governance/utils/Votes.sol)
pragma solidity ^0.8.0;

import "../../interfaces/IERC5805Upgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/CountersUpgradeable.sol";
import "../../utils/CheckpointsUpgradeable.sol";
import "../../utils/cryptography/EIP712Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev This is a base abstract contract that tracks voting units, which are a measure of voting power that can be
 * transferred, and provides a system of vote delegation, where an account can delegate its voting units to a sort of
 * "representative" that will pool delegated voting units from different accounts and can then use it to vote in
 * decisions. In fact, voting units _must_ be delegated in order to count as actual votes, and an account has to
 * delegate those votes to itself if it wishes to participate in decisions and does not have a trusted representative.
 *
 * This contract is often combined with a token contract such that voting units correspond to token units. For an
 * example, see {ERC721Votes}.
 *
 * The full history of delegate votes is tracked on-chain so that governance protocols can consider votes as distributed
 * at a particular block number to protect against flash loans and double voting. The opt-in delegate system makes the
 * cost of this history tracking optional.
 *
 * When using this module the derived contract must implement {_getVotingUnits} (for example, make it return
 * {ERC721-balanceOf}), and can use {_transferVotingUnits} to track a change in the distribution of those units (in the
 * previous example, it would be included in {ERC721-_beforeTokenTransfer}).
 *4 insertions 45 deletions
 * _Available since v4.5._
 *  
 * FORK INFORMATION
 * This contract has been modified for use in thunderhead-labs/stflip-contracts. stFLIP is an LST that also serves as a voting
 * token in governance to ensure it remains non-custodial. Voting should not be opt-in to ensure users keep control.
 * 
 * Modifications made in order of appearance:
 * 1. No longer inherits `ContextUpgradeable, EIP712Upgradeable, IERC5805Upgradeable` since it does not fit those interfaces
 * anymore
 * 2. Removed `_DELEGATION_TYPEHASH, _delegation, _nonces` since delegation is disabled. The "delegate" for an address is itself
 * 3. Removed functions `_delegate, delegateBySig, delegate` since delegation is disabled
 * 4. Modified `delegates(address who)` to always return `who`
 * 5. Changed `_moveDelegateVotes(delegates(from), delegates(to), amount)` to `_moveDelegateVotes(from, to, amount)` since an address delegates to itself
 * 6. Removed `DelegateVotesChanged` emission in `_moveDelegateVotes` since `Transfer` makes it redundant
 * 7. Removed functions `_useNonce, nonces, DOMAIN_SEPARATOR, _getVotingUnits` since delegation is disabled
 * 8. Increased __gap length by 2 to account for previously removed variables
 * 
 * This change is 4/45 source insertions and deletions respectively
 */
abstract contract VotesUpgradeable is Initializable, IERC5805Upgradeable {
    function __Votes_init() internal onlyInitializing {
    }

    function __Votes_init_unchained() internal onlyInitializing {
    }
    using CheckpointsUpgradeable for CheckpointsUpgradeable.Trace224;

    /// @custom:oz-retyped-from mapping(address => Checkpoints.History)
    mapping(address => CheckpointsUpgradeable.Trace224) private _delegateCheckpoints;

    /// @custom:oz-retyped-from Checkpoints.History
    CheckpointsUpgradeable.Trace224 private _totalCheckpoints;

    /**
     * @dev Clock used for flagging checkpoints. Can be overridden to implement timestamp based
     * checkpoints (and voting), in which case {CLOCK_MODE} should be overridden as well to match.
     */
    function clock() public view virtual override returns (uint48) {
        return SafeCastUpgradeable.toUint48(block.number);
    }

    /**
     * @dev Machine-readable description of the clock as specified in EIP-6372.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual override returns (string memory) {
        // Check that the clock was not modified
        require(clock() == block.number, "Votes: broken clock mode");
        return "mode=blocknumber&from=default";
    }

    /**
     * @dev Returns the current amount of votes that `account` has.
     */
    function getVotes(address account) public view virtual override returns (uint256) {
        return _delegateCheckpoints[account].latest();
    }

    /**
     * @dev Returns the amount of votes that `account` had at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     *
     * Requirements:
     *
     * - `timepoint` must be in the past. If operating using block numbers, the block must be already mined.
     */
    function getPastVotes(address account, uint256 timepoint) public view virtual override returns (uint256) {
        require(timepoint < clock(), "Votes: future lookup");
        return _delegateCheckpoints[account].upperLookupRecent(SafeCastUpgradeable.toUint32(timepoint));
    }

    /**
     * @dev Returns the total supply of votes available at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     *
     * NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
     * Votes that have not been delegated are still part of total supply, even though they would not participate in a
     * vote.
     *
     * Requirements:
     *
     * - `timepoint` must be in the past. If operating using block numbers, the block must be already mined.
     */
    function getPastTotalSupply(uint256 timepoint) public view virtual override returns (uint256) {
        require(timepoint < clock(), "Votes: future lookup");
        return _totalCheckpoints.upperLookupRecent(SafeCastUpgradeable.toUint32(timepoint));
    }

    /**
     * @dev Returns the current total supply of votes.
     */
    function _getTotalSupply() internal view virtual returns (uint256) {
        return _totalCheckpoints.latest();
    }

    /**
     * @dev Returns the delegate that `account` has chosen.
     */
    function delegates(address account) public view virtual override returns (address) {
        return account;
    }

    /**
     * @dev Transfers, mints, or burns voting units. To register a mint, `from` should be zero. To register a burn, `to`
     * should be zero. Total supply of voting units will be adjusted with mints and burns.
     */
    function _transferVotingUnits(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            _push(_totalCheckpoints, _add, SafeCastUpgradeable.toUint224(amount));
        }
        if (to == address(0)) {
            _push(_totalCheckpoints, _subtract, SafeCastUpgradeable.toUint224(amount));
        }
        _moveDelegateVotes(from, to, amount);
    }

    /**
     * @dev Moves delegated votes from one delegate to another.
     */
    function _moveDelegateVotes(address from, address to, uint256 amount) private {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[from],
                    _subtract,
                    SafeCastUpgradeable.toUint224(amount)
                );
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[to],
                    _add,
                    SafeCastUpgradeable.toUint224(amount)
                );
            }
        }
    }

    function _push(
        CheckpointsUpgradeable.Trace224 storage store,
        function(uint224, uint224) view returns (uint224) op,
        uint224 delta
    ) private returns (uint224, uint224) {
        return store.push(SafeCastUpgradeable.toUint32(clock()), op(store.latest(), delta));
    }

    function _add(uint224 a, uint224 b) private pure returns (uint224) {
        return a + b;
    }

    function _subtract(uint224 a, uint224 b) private pure returns (uint224) {
        return a - b;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
