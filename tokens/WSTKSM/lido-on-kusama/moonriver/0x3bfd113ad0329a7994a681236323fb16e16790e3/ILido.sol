// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "Types.sol";

interface ILido {
    function MAX_ALLOWABLE_DIFFERENCE() external view returns(uint128);

    function developers() external view returns(address);

    function deposit(uint256 amount) external returns (uint256);
    
    function distributeRewards(uint256 totalRewards, uint256 ledgerBalance) external;

    function distributeLosses(uint256 totalLosses, uint256 ledgerBalance) external;

    function getStashAccounts() external view returns (bytes32[] memory);

    function getLedgerAddresses() external view returns (address[] memory);

    function ledgerStake(address ledger) external view returns (uint256);

    function ledgerShares(address ledger) external view returns (uint256);

    function avaliableForStake() external view returns (uint256);

    function transferFromLedger(uint256 amount) external;

    function transferToLedger(uint256 amount) external;

    function flushStakes() external;

    function findLedger(bytes32 stash) external view returns (address);

    function AUTH_MANAGER() external returns(address);

    function ORACLE_MASTER() external view returns (address);

    function getPooledKSMByShares(uint256 sharesAmount) external view returns (uint256);

    function getSharesByPooledKSM(uint256 amount) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
