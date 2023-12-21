// SPDX-License-Identifier: None
pragma solidity ^0.8.19;

interface IProofToken {
    struct Tax {
        uint16 revenueRate;
        uint16 stakingRate;
        uint16 ventureFundRate;
    }

    /// @notice Enable/Disable trading.
    /// @dev Only owner can call this function.
    function enableTrading(bool _enable) external;

    /// @notice Set maxWallet amount.
    /// @dev ONly owner can call this function.
    function setMaxWallet(uint256 _maxWallet) external;

    /// @notice Set maxTransfer amount.
    /// @dev Only owner can call this function.
    function setMaxTransfer(uint256 _maxTransfer) external;

    /// @notice Set revenue address.
    /// @dev Only owner can call this function.
    function setRevenue(address _revenue) external;

    /// @notice Set Staking contract address.
    /// @dev Only owner can call this function.
    function setStakingContract(address _staking) external;

    /// @notice Set venture fund address.
    /// @dev Only owner can call this function.
    function setVentureFund(address _ventureFund) external;

    /// @notice Set tax for buy.
    /// @dev Only owner can call this function.
    function setTaxForBuy(Tax memory _tax) external;

    /// @notice Set tax for sell.
    /// @dev Only owner can call this function.
    function setTaxForSell(Tax memory _tax) external;

    /// @notice Withdraw rest Proof token after airdrop.
    /// @dev This can be called by only owner.
    function withdrawRestAmount(uint256 _amount) external;

    /// @notice Set new SwapThreshold amount and enable swap flag.
    /// @dev Only owner can call this function.
    function setSwapBackSettings(
        uint256 _swapThreshold,
        bool _swapEnable
    ) external;

    /// @notice Exclude wallets from TxLimit.
    /// @dev Only owner can call this function.
    function excludeWalletsFromTxLimit(
        address[] memory _wallets,
        bool _exclude
    ) external;

    /// @notice Exclude wallets from MaxWallet.
    /// @dev Only owner can call this function.
    function excludeWalletsFromMaxWallet(
        address[] memory _wallets,
        bool _exclude
    ) external;

    /// @notice Exclude wallets from Tax Fees.
    /// @dev Only owner can call this function.
    function excludeWalletsFromFees(
        address[] memory _wallets,
        bool _exclude
    ) external;
}
