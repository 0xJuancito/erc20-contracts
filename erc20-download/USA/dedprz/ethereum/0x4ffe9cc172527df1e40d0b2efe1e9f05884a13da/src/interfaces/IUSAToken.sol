// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IUSAToken {
    event WithdrawTokens(address indexed token, address indexed to, uint256 amount);
    event MinterRemoved(address indexed minter);
    event MinterAdded(address _minter);
    event TaxFeeOnBuyChanged(uint256 taxFeeOnBuy);
    event TaxFeeOnSellChanged(uint256 taxFeeOnSell);
    event DaoTaxReceiverChanged(address _daoTaxReceiver);
    event FeeStatus(bool _value);
    event SwapToEthOnSellChanged(bool swapToEthOnSell);
    event ExcludedFromFeeChanged(address indexed _address, bool _excluded);
    event MinSwapAmountChanged(uint256 _minSwapAmount);
    event SwapHelperChanged(address _swapRouter);
    event RegisteredSwapContract(address indexed _swapContract, bool _setting);
    event PoolFeeChanged(uint24 _poolFee);
    event BlacklistAddress(address indexed account, bool value);
}
