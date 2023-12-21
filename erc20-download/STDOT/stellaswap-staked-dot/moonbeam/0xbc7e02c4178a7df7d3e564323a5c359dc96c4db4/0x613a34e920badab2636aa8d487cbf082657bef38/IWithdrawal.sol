// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWithdrawal {
    // total virtual xcTOKEN amount on contract
    function totalVirtualXcTokenAmount() external returns (uint256);

    // nTOKEN(xcTOKEN) virtual amount for batch
    function batchVirtualXcTokenAmount() external returns (uint256);

    // Set nTOKEN contract address, allowed to only once
    function setNTOKEN(address _nTOKEN) external;

    // Returns total virtual xcTOKEN balance of contract for which losses can be applied
    function totalBalanceForLosses() external view returns (uint256);

    // Returns total xcTOKEN balance of contract which waiting for claim
    function pendingForClaiming() external view returns (uint256);

    // Burn pool shares from first element of queue and move index for allow claiming. After that add new batch
    function newEra() external;

    // Mint equal amount of pool shares for user. Adjust current amount of virtual xcTOKEN on Withdrawal contract.
    // Burn shares on Nimbus side
    function redeem(address _from, uint256 _amount) external;

    // Returns available for claiming xcTOKEN amount for user
    function claim(address _holder) external returns (uint256);

    // Apply losses to current nTOKEN shares on this contract
    function ditributeLosses(uint256 _losses) external;

    // Check available for claim xcTOKEN balance for user
    function getRedeemStatus(address _holder) external view returns(uint256 _waiting, uint256 _available);
}