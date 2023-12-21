// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

interface IFeeManager {
    function getTxFeeWeekday() external view returns (uint256 txFee);

    function getTxFeeWeekend() external view returns (uint256 txFee);

    function getMinMaxDeposit()
        external
        view
        returns (uint256 minDeposit, uint256 maxDeposit);

    function getMinMaxWithdraw()
        external
        view
        returns (uint256 minWithdraw, uint256 maxWithdraw);

    function getManagementFeeRate() external view returns (uint256 feeRate);

    function getFirstDeposit() external view returns (uint256 firstDeposit);

    function getMaxWeekendDepositPct()
        external
        view
        returns (uint256 maxDepositPct, uint256 maxDepositAggregatedPct);

    function getMinTxsFee() external view returns (uint256);
}
