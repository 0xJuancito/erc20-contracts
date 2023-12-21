// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

interface IIssuer {
    function issueDebt(
        bytes32 stake,
        address account,
        bytes32 debtType,
        uint256 amountInUSD,
        uint256 amountInSynth
    ) external;

    function issueDebtWithPreviousStake(
        bytes32 stake, 
        address account, 
        bytes32 debtType, 
        uint256 amountInSynth
    ) external;

    function getIssuable(bytes32 stake, address account, bytes32 debtType) external view returns (uint256);

    function burnDebt(
        bytes32 stake,
        address account,
        bytes32 debtType,
        uint256 amount,
        address payer
    ) external returns (uint256);

    function issueSynth(
        bytes32 synth,
        address account,
        uint256 amount
    ) external;

    function burnSynth(
        bytes32 synth,
        address account,
        uint256 amount
    ) external;

    function getDebt(bytes32 stake, address account, bytes32 debtType) external view returns (uint256);
    function getDebtOriginal(bytes32 stake, address account, bytes32 debtType) external view returns (uint256, uint256, uint256);
    function getUsersTotalDebtInSynth(bytes32 synth) external view returns (uint256);

    function getDynamicTotalDebt() external view returns (uint256 platTotalDebt, uint256 usersTotalDebt, uint256 usersTotalDebtOriginal);

}
