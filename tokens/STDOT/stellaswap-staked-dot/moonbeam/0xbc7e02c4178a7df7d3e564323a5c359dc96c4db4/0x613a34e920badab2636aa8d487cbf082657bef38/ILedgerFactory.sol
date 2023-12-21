// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILedgerFactory {
    function createLedger(
        bytes32 _stashAccount,
        bytes32 _controllerAccount,
        address _xcTOKEN,
        address _controller,
        uint128 _minNominatorBalance,
        uint128 _minimumBalance,
        uint256 _maxUnlockingChunks
    ) external returns (address);
}