// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

import "./_Token.sol";

abstract contract Locks is Token {

    /**
     * @dev Stores data for individual token locks used by transferAndLock.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    struct Lock {
        uint256 value;
        uint64 expiration;
        uint32 periodLength;
        uint16 periods;
        bool staking;
    }

    mapping(address => Lock[]) locks;

    event Locked(
        address indexed owner,
        uint256 value,
        uint64 expiration,
        uint32 periodLength,
        uint16 periodCount
    );
    event Unlocked(address indexed owner, uint256 value, uint16 periodsLeft);


    /**
     * @dev Lists all the locks for the given account as an array, with [value1, expiration1, value2, expiration2, ...]
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function locksOf(address account) public view returns (uint256[] memory) {
        Lock[] storage userLocks = locks[account];

        uint256[] memory lockArray = new uint256[](userLocks.length * 4);

        for (uint256 i = 0; i < userLocks.length; i++) {
            uint256 pos = 4 * i;
            lockArray[pos] = userLocks[i].value;
            lockArray[pos + 1] = userLocks[i].expiration;
            lockArray[pos + 2] = userLocks[i].periodLength;
            lockArray[pos + 3] = userLocks[i].periods;
        }

        return lockArray;
    }

    /**
     * @dev Unlocks all expired locks.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function unlock() public returns (bool) {
        return _unlock(msg.sender);
    }

    /**
     * @dev Base method for unlocking tokens.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function _unlock(address account) internal returns (bool) {
        Lock[] storage list = locks[account];
        if (list.length == 0) {
            return true;
        }

        for (uint256 i = 0; i < list.length; ) {
            Lock storage lock = list[i];
            if (lock.expiration < block.timestamp) {
                // Less than 2 means it's the last period (1), or periods are not used (0)
                if (lock.periods < 2) {
                    emit Unlocked(account, lock.value, 0);

                    if (i < list.length - 1) {
                        list[i] = list[list.length - 1];
                    }
                    list.pop();
                } else {
                    uint256 value;
                    uint256 diff = block.timestamp - lock.expiration;
                    uint16 periodsPassed = 1 + uint16(diff / lock.periodLength);
                    if (periodsPassed >= lock.periods) {
                        periodsPassed = lock.periods;
                        value = lock.value;
                        emit Unlocked(account, value, 0);
                        if (i < list.length - 1) {
                            list[i] = list[list.length - 1];
                        }
                        list.pop();
                    } else {
                        value = (lock.value / lock.periods) * periodsPassed;

                        lock.periods -= periodsPassed;
                        lock.value -= value;
                        lock.expiration += uint32(uint256(lock.periodLength) * periodsPassed);
                        emit Unlocked(account, value, lock.periods);
                        i++;
                    }
                }
            } else {
                i++;
            }
        }

        return true;
    }

    /**
     * @dev Gets the unlocked balance of the specified address.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function unlockedBalanceOf(address account) public view returns (uint256) {
        return balances[account] - totalLocked(account);
    }

    /**
     * @dev Gets the total usable tokens for an account, including tokens that could be unlocked.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function availableBalanceOf(address account) external view returns (uint256) {
        return balances[account] - totalLocked(account) + totalUnlockable(account);
    }

    /**
     * @dev Transfers tokens and locks them for lockTime.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function transferAndLock(
        address to,
        uint256 value,
        uint32 lockTime,
        uint32 periodLength,
        uint16 periods
    ) public returns (bool) {
        uint64 expires = uint64(block.timestamp + lockTime);
        Lock memory newLock = Lock(value, expires, periodLength, periods, false);
        locks[to].push(newLock);

        transfer(to, value);
        emit Locked(to, value, expires, periodLength, periods);

        return true;
    }

    /**
     * @dev Gets the total amount of locked tokens in the given account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function totalLocked(address account) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < locks[account].length; i++) {
            total += locks[account][i].value;
        }

        return total;
    }

    /**
     * @dev Gets the amount of tokens that can currently be unlocked.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function totalUnlockable(address account) public view returns (uint256) {
        Lock[] storage userLocks = locks[account];
        uint256 total = 0;
        for (uint256 i = 0; i < userLocks.length; i++) {
            Lock storage lock = userLocks[i];
            if (lock.expiration < block.timestamp) {
                if (lock.periods < 2) {
                    total += lock.value;
                } else {
                    uint256 value;
                    uint256 diff = block.timestamp - lock.expiration;
                    uint16 periodsPassed = 1 + uint16(diff / lock.periodLength);
                    if (periodsPassed > lock.periods) {
                        periodsPassed = lock.periods;
                        value = lock.value;
                    } else {
                        value = (lock.value / lock.periods) * periodsPassed;
                    }

                    total += value;
                }
            }
        }

        return total;
    }


    /**
     * @dev Base method for transferring tokens.
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal override {
        _unlock(from);
        expect(value <= unlockedBalanceOf(from), ERROR_INSUFFICIENT_BALANCE);

        super._transfer(from, to, value);
    }
}
