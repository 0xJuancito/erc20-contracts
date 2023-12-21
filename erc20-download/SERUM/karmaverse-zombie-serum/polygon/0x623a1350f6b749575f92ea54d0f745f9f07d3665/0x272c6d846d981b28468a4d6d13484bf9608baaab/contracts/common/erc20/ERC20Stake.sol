//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "../access/GameAdmin.sol";
import "../base/ClaimTimer.sol";
import "../base/TxIdempotent.sol";

abstract contract ERC20Stake is GameAdmin, ClaimTimer, TxIdempotent {

    uint256 internal constant CLAIM_TIMEOUT = 10 minutes;

    event TokenWithdrew(address toAccount, uint256 amount, uint64 txId, uint64 timestamp);
    event TokenDeposited(address fromAccount, uint256 amount, bool feeClaimed);

    error IllegalAmount();
    error OpTimeout();
    error OpCoolingDown();
    error IllegalSignature();

    function withdraw(address account, uint256 amount, uint64 txId, uint64 timestamp, bytes memory signature) public virtual idempotent(txId) {
        if (amount <= 0) revert IllegalAmount();
        if (block.timestamp >= timestamp + CLAIM_TIMEOUT) revert OpTimeout();
        if (_getClaimTs(account) + CLAIM_TIMEOUT >= timestamp) revert OpCoolingDown();
        if (!_verifyWithdraw(account, amount, txId, timestamp, signature)) revert IllegalSignature();
        _transferFromContract(account, amount);
        _setClaimTs(account, timestamp);
        emit TokenWithdrew(account, amount, txId, timestamp);
    }

    function _verifyWithdraw(address account, uint256 amount, uint64 txId, uint64 timestamp, bytes memory signature) internal view returns (bool) {
        bytes32 hash = keccak256(abi.encode(account, amount, txId, timestamp));
        bytes32 signedHash = ECDSAUpgradeable.toEthSignedMessageHash(hash);
        return verify(signedHash, signature);
    }

    function deposit(uint256 amount) public virtual {
        bool feeClaimed = _transferToContract(msg.sender, amount);
        emit TokenDeposited(msg.sender, amount, feeClaimed);
    }

    function _transferFromContract(address toAccount, uint256 amount) internal virtual;
    function _transferToContract(address fromAccount, uint256 amount) internal virtual returns (bool);
}