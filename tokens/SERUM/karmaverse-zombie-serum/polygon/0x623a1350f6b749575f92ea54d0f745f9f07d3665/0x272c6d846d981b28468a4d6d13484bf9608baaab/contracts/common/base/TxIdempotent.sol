//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

abstract contract TxIdempotent {

    mapping(uint64 => bool) private txRecords;

    error TxAlreadySolved(uint64 txId);

    modifier idempotent(uint64 txId) {
        if (txId > 0) {
            if (txRecords[txId]) revert TxAlreadySolved({txId: txId});
            txRecords[txId] = true;
        }
        _;
    }
}