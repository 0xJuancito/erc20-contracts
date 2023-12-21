// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

import "./_MultiTransfer.sol";

abstract contract Staking is MultiTransfer {
    struct StakeData {
        uint256 value;
        uint64 expiration;
        uint64 time;
    }

    mapping(address => StakeData[]) internal stakes;
    uint256 public unstakingDelay = 1 hours;

    event Stake(address indexed account, uint256 value, uint64 time);
    event Unstake(address indexed account, uint256 value);
    event StakeReward(address indexed account, uint256 value);

    /**
     * @dev Stake tokens, locking them for a minimum of unstakingDelay time.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function stake(uint256 value, uint64 stakeLockupTime) public whenNotPaused whenUnlocked returns (bool) {
        expect(!isFrozen(msg.sender), ERROR_FROZEN);

        _unlock(msg.sender);
        expect(value <= unlockedBalanceOf(msg.sender), ERROR_INSUFFICIENT_BALANCE);

        _stake(msg.sender, value, stakeLockupTime);

        return true;
    }

    /**
     * @dev Get the total staked tokens for an account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function stakeOf(address account) public view returns (uint256) {
        StakeData[] storage list = stakes[account];
        uint256 total = 0;

        for (uint256 i = list.length; i > 0; i--) {
            total += list[i - 1].value;
        }
        return total;
    }

    function allStakes(address account) public view returns (StakeData[] memory) {
        return stakes[account];
    }

    /**
     * @dev Unstake tokens, which will lock them for unstakingDelay time.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function unstake(uint256 value) public whenNotPaused whenUnlocked returns (bool) {
        expect(!isFrozen(msg.sender), ERROR_FROZEN);

        uint256 remaining = value;
        StakeData[] storage list = stakes[msg.sender];

        expect(list.length > 0, ERROR_DISALLOWED_STATE);

        for (uint256 i = list.length; i > 0; i--) {
            StakeData storage it = list[i - 1];
            if (it.expiration <= block.timestamp) {
                if (it.value >= remaining) {
                    it.value -= remaining;
                    remaining = 0;
                } else {
                    remaining -= it.value;
                    it.value = 0;
                }

                // As long as we're still looking at the last item, and it's now 0, pop it
                if (it.value == 0 && i == list.length) {
                    list.pop();
                }
            }
            if (remaining == 0) {
                break;
            }
        }

        expect(remaining == 0, ERROR_TOO_HIGH);

        if (unstakingDelay > 0) {
            uint64 expires = uint64(block.timestamp + unstakingDelay);
            Lock memory newLock = Lock(value, expires, 0, 0, true);
            locks[msg.sender].push(newLock);
            emit Locked(msg.sender, value, expires, 0, 0);
        }

        emit Unstake(msg.sender, value);
        balances[msg.sender] += value;
        emit Transfer(address(0), msg.sender, value);

        return true;
    }

    /**
     * @dev Configure staking parameters.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function configureStaking(uint256 unstakeDelay) public onlyAdminOrAttorney {
        unstakingDelay = unstakeDelay;
    }

    /**
     * @dev Reward tokens to account stake balances.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function stakeReward(address[] calldata to, uint256[] calldata value)
        public
        whenNotPaused
        returns (bool)
    {
        expect(isAutomator(msg.sender), ERROR_UNAUTHORIZED);
        expect(value.length == to.length, ERROR_LENGTH_MISMATCH);

        for (uint256 i = 0; i < to.length; i++) {
            address account = to[i];
            uint256 val = value[i];
            if (!isFrozen(account)) {
                balances[msg.sender] -= val;
                stakes[account].push(StakeData(val, uint64(block.timestamp), 0));

                emit StakeReward(account, val);
                emit Transfer(msg.sender, address(0), val);
            }
        }

        return true;
    }

    /**
     * @dev Perform staking on the given account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function _stake(address account, uint256 value, uint64 stakeLockupTime) internal {
        balances[account] -= value;
        stakes[account].push(StakeData(value, uint64(block.timestamp) + stakeLockupTime, stakeLockupTime));

        emit Transfer(account, address(0), value);
        emit Stake(account, value, stakeLockupTime);
    }
}
