// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

import "./_Locks.sol";

abstract contract MultiTransfer is Locks {

    event MultiTransferPrevented(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Make multiple token transfers with one transaction.
     * @param to Array of addresses to transfer to.
     * @param value Array of amounts to be transferred.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function multiTransfer(address[] calldata to, uint256[] calldata value)
    public
    whenNotPaused
    onlyBundler
    returns (bool)
    {
        expect(to.length > 0, ERROR_EMPTY_ARRAY);
        expect(value.length == to.length, ERROR_LENGTH_MISMATCH);

        for (uint256 i = 0; i < to.length; i++) {
            if (!isFrozen(to[i])) {
                _transfer(msg.sender, to[i], value[i]);
            } else {
                emit MultiTransferPrevented(msg.sender, to[i], value[i]);
            }
        }

        return true;
    }

    /**
     * @dev Transfer tokens from one address to multiple others.
     * @param from Address to send from.
     * @param to Array of addresses to transfer to.
     * @param value Array of amounts to be transferred.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function multiTransferFrom(
        address from,
        address[] calldata to,
        uint256[] calldata value
    ) public whenNotPaused onlyBundler returns (bool) {
        expect(to.length > 0, ERROR_EMPTY_ARRAY);
        expect(value.length == to.length, ERROR_LENGTH_MISMATCH);

        for (uint256 i = 0; i < to.length; i++) {
            if (!isFrozen(to[i])) {
                allowed[from][msg.sender] -= value[i];
                _transfer(from, to[i], value[i]);
            } else {
                emit MultiTransferPrevented(from, to[i], value[i]);
            }
        }

        return true;
    }


    /**
     * @dev Transfer and lock to multiple accounts with a single transaction.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function multiTransferAndLock(
        address[] calldata to,
        uint256[] calldata value,
        uint32 lockTime,
        uint32 periodLength,
        uint16 periods
    ) public whenNotPaused onlyBundler returns (bool) {
        expect(to.length > 0, ERROR_EMPTY_ARRAY);
        expect(value.length == to.length, ERROR_LENGTH_MISMATCH);

        for (uint256 i = 0; i < to.length; i++) {
            if (!isFrozen(to[i])) {
                transferAndLock(to[i], value[i], lockTime, periodLength, periods);
            } else {
                emit MultiTransferPrevented(msg.sender, to[i], value[i]);
            }
        }

        return true;
    }
}
