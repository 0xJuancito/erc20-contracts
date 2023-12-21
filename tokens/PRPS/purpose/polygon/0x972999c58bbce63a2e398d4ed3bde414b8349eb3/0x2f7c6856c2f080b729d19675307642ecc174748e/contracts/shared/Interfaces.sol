//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IDubi {
    function purposeMint(address to, uint96 amount) external;

    function hodlMint(address to, uint96 amount) external;
}

interface IPurpose {
    function migrateLockedPrps(address to, uint96 amount) external;

    function lockPrps(
        address creator,
        address prpsBeneficiary,
        uint96 amount
    ) external;

    function unlockPrps(address from, uint96 amount) external;
}

interface IHodl {
    function purposeLockedBurn(
        address from,
        uint96 amount,
        uint32 dubiMintTimestamp,
        bytes32[] calldata hodlKeys
    ) external returns (uint96);
}
