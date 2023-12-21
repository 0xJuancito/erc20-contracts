// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

enum ServiceFeeType {
    ONCHAIN,
    OFFCHAIN
}

interface IOpenEdenVault {
    event Deposit(address indexed receiver, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event SetOplTreasury(address oplTreasury);
    event UpdateTreasury(address newAddress);
    event UpdateQTreasury(address newAddress);

    event SetFeeManager(address feeManager);
    event SetKycManager(address kycManager);
    event SetTimelock(address timelock);
    event SetOperator(address operator);
    event SetUsdcPriceFeed(address priceFeed);
    event SetTBillPriceFeed(address priceFeed);
    event SetController(address controller);
    event SetMaxDepeg(uint256 max);
    event SetMaxTimeDelay(uint256 maxTimeDelay);

    event ClaimServiceFee(address receiver, uint256 amount);
    event UpdateEpoch(uint256 unClaimedFee, uint256 epoch, bool isWeekend);
    event SetWeekendFlag(bool flag);
    event AddToWithdrawalQueue(
        address sender,
        address receiver,
        uint256 shares,
        bytes32 id
    );
    event ProcessWithdrawalQueue(
        uint256 totalAssets,
        uint256 totalShares,
        uint256 totalFees
    );
    event OffRamp(address treasury, uint256 assets);
    event OffRampQ(address qTreasury, uint256 assets);
    event ProcessDeposit(
        address sender,
        address receiver,
        uint256 assets,
        uint256 shares,
        uint256 txsFee,
        address oplTreasury,
        address treasury
    );
    event ProcessWithdraw(
        address sender,
        address receiver,
        uint256 assets,
        uint256 shares,
        uint256 actualAssets,
        uint256 actualShare,
        uint256 txFee,
        bytes32 prevId,
        address oplTreasury
    );
    event ProcessRedeemCancel(
        address sender,
        address receiver,
        uint256 shares,
        bytes32 prevId
    );
    event Cancel(uint256 len, uint256 totalShares);
}
