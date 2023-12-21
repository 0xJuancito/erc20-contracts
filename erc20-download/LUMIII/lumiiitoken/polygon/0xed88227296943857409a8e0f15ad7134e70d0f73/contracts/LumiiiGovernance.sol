pragma solidity ^0.6.6;

import "./LumiiiStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LumiiiGovernance is LumiiiStorage, Ownable{
    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    /** 
        @notice Gets prior number of votes for an account as of given blockNumber
        @param account Address of account to check
        @param blockNumber Block number to get votes at
    */
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "LIFE::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // Check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Check implicit zero balance -> returning here
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        // Binary search
        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    /** 
        @notice Gets current votes for an account
        @param account Address to get votes of
    */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /** 
        @notice Get delegatee for an address delegating
        @param delegator Address to get delegatee for
    */
    function delegates(address delegator) external view returns (address) {
        return _delegates[delegator];
    }

    /** 
        @notice Move delegates from srcRep address to dstRep. If ether are the address, delegates are
        increased/decreased accordingly rather than moved.
        @param srcRep Address to move delegates from 
        @param dstRep Address to move delegates to
        @param amount Amount of delegates to mvoe
    */
    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0
                ? checkpoints[srcRep][srcRepNum - 1].votes
                : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep]; 
                uint256 dstRepOld = dstRepNum > 0
                ? checkpoints[dstRep][dstRepNum - 1].votes
                : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    /** 
        @notice Writes new checkpoint for delegatee with new votes and block number
        @param delegatee Address for new checkppint
        @param nCheckpoints Number of checkpoints for delegatee
        @param oldVotes Number of votes for delegatee at old checkpoint
        @param newVotes Number of votes for delegatee at new checkpoint
    */
    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        require(block.number < 2**32, "block number exceeds 32 bits");
        uint32 blockNumber = uint32(block.number);

        if (
        nCheckpoints > 0 &&
        checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes); // Checkpoint object
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }
}