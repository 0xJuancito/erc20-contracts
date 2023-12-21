/*
https://revhuberc.com
https://twitter.com/RevhubERC
https://t.me/Revhubercportal
*/


// SPDX-License-Identifier: No License
pragma solidity 0.8.19;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol";
import "./Initializable.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapV2Router02.sol";

contract Revhub is ERC20, ERC20Burnable, Ownable, Initializable {
    
    uint256 public swapThreshold;
    
    uint256 private _buybackandlpPending;
    uint256 private _revsharePending;
    uint256 private _backendPending;

    address public buybackandlpAddress;
    uint16[3] public buybackandlpFees;

    address public revshareAddress;
    uint16[3] public revshareFees;

    address public backendAddress;
    uint16[3] public backendFees;

    mapping (address => bool) public isExcludedFromFees;

    uint16[3] public totalFees;
    bool private _swapping;

    IUniswapV2Router02 public routerV2;
    address public pairV2;
    mapping (address => bool) public AMMPairs;

    mapping (address => bool) public isExcludedFromLimits;

    uint256 public maxWalletAmount;
 
    event SwapThresholdUpdated(uint256 swapThreshold);

    event buybackandlpAddressUpdated(address buybackandlpAddress);
    event buybackandlpFeesUpdated(uint16 buyFee, uint16 sellFee, uint16 transferFee);
    event buybackandlpFeeSent(address recipient, uint256 amount);

    event revshareAddressUpdated(address revshareAddress);
    event revshareFeesUpdated(uint16 buyFee, uint16 sellFee, uint16 transferFee);
    event revshareFeeSent(address recipient, uint256 amount);

    event backendAddressUpdated(address backendAddress);
    event backendFeesUpdated(uint16 buyFee, uint16 sellFee, uint16 transferFee);
    event backendFeeSent(address recipient, uint256 amount);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event RouterV2Updated(address indexed routerV2);
    event AMMPairsUpdated(address indexed AMMPair, bool isPair);

    event ExcludeFromLimits(address indexed account, bool isExcluded);

    event MaxWalletAmountUpdated(uint256 maxWalletAmount);
 
    constructor()
        ERC20(unicode"Revhub", unicode"Revhub") 
    {
        address supplyRecipient = 0x4D880587296D3F735Da062f12bC93b3Dc89F64F7;
        
        updateSwapThreshold(10000000 * (10 ** decimals()) / 10);

        buybackandlpAddressSetup(0x041dc532F1122ed4Fd9ba8431c56bC755958E041);
        buybackandlpFeesSetup(100, 100, 0);

        revshareAddressSetup(0x76Dd2b50Ce4aa47865223F607A19b72a7D050b5d);
        revshareFeesSetup(100, 100, 0);

        backendAddressSetup(0xc5ef687b1b588273C4d84B947Dec1af7aDcfC1b4);
        backendFeesSetup(300, 300, 0);

        excludeFromFees(supplyRecipient, true);
        excludeFromFees(address(this), true); 

        _excludeFromLimits(supplyRecipient, true);
        _excludeFromLimits(address(this), true);
        _excludeFromLimits(address(0), true); 
        _excludeFromLimits(buybackandlpAddress, true);
        _excludeFromLimits(revshareAddress, true);
        _excludeFromLimits(backendAddress, true);

        updateMaxWalletAmount(30000000 * (10 ** decimals()) / 10);

        _mint(supplyRecipient, 10000000000 * (10 ** decimals()) / 10);
        _transferOwnership(0x4D880587296D3F735Da062f12bC93b3Dc89F64F7);
    }
    
    function initialize(address _router) initializer external {
        _updateRouterV2(_router);
    }

    receive() external payable {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    function _swapTokensForCoin(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = routerV2.WETH();

        _approve(address(this), address(routerV2), tokenAmount);

        routerV2.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function updateSwapThreshold(uint256 _swapThreshold) public onlyOwner {
        swapThreshold = _swapThreshold;
        
        emit SwapThresholdUpdated(_swapThreshold);
    }

    function getAllPending() public view returns (uint256) {
        return 0 + _buybackandlpPending + _revsharePending + _backendPending;
    }

    function buybackandlpAddressSetup(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "TaxesDefaultRouterWallet: Wallet tax recipient cannot be a 0x0 address");

        buybackandlpAddress = _newAddress;
        excludeFromFees(_newAddress, true);

        emit buybackandlpAddressUpdated(_newAddress);
    }

    function buybackandlpFeesSetup(uint16 _buyFee, uint16 _sellFee, uint16 _transferFee) public onlyOwner {
        totalFees[0] = totalFees[0] - buybackandlpFees[0] + _buyFee;
        totalFees[1] = totalFees[1] - buybackandlpFees[1] + _sellFee;
        totalFees[2] = totalFees[2] - buybackandlpFees[2] + _transferFee;
        require(totalFees[0] <= 2500 && totalFees[1] <= 2500 && totalFees[2] <= 2500, "TaxesDefaultRouter: Cannot exceed max total fee of 25%");

        buybackandlpFees = [_buyFee, _sellFee, _transferFee];

        emit buybackandlpFeesUpdated(_buyFee, _sellFee, _transferFee);
    }

    function revshareAddressSetup(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "TaxesDefaultRouterWallet: Wallet tax recipient cannot be a 0x0 address");

        revshareAddress = _newAddress;
        excludeFromFees(_newAddress, true);

        emit revshareAddressUpdated(_newAddress);
    }

    function revshareFeesSetup(uint16 _buyFee, uint16 _sellFee, uint16 _transferFee) public onlyOwner {
        totalFees[0] = totalFees[0] - revshareFees[0] + _buyFee;
        totalFees[1] = totalFees[1] - revshareFees[1] + _sellFee;
        totalFees[2] = totalFees[2] - revshareFees[2] + _transferFee;
        require(totalFees[0] <= 2500 && totalFees[1] <= 2500 && totalFees[2] <= 2500, "TaxesDefaultRouter: Cannot exceed max total fee of 25%");

        revshareFees = [_buyFee, _sellFee, _transferFee];

        emit revshareFeesUpdated(_buyFee, _sellFee, _transferFee);
    }

    function backendAddressSetup(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "TaxesDefaultRouterWallet: Wallet tax recipient cannot be a 0x0 address");

        backendAddress = _newAddress;
        excludeFromFees(_newAddress, true);

        emit backendAddressUpdated(_newAddress);
    }

    function backendFeesSetup(uint16 _buyFee, uint16 _sellFee, uint16 _transferFee) public onlyOwner {
        totalFees[0] = totalFees[0] - backendFees[0] + _buyFee;
        totalFees[1] = totalFees[1] - backendFees[1] + _sellFee;
        totalFees[2] = totalFees[2] - backendFees[2] + _transferFee;
        require(totalFees[0] <= 2500 && totalFees[1] <= 2500 && totalFees[2] <= 2500, "TaxesDefaultRouter: Cannot exceed max total fee of 25%");

        backendFees = [_buyFee, _sellFee, _transferFee];

        emit backendFeesUpdated(_buyFee, _sellFee, _transferFee);
    }

    function excludeFromFees(address account, bool isExcluded) public onlyOwner {
        isExcludedFromFees[account] = isExcluded;
        
        emit ExcludeFromFees(account, isExcluded);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        
        bool canSwap = getAllPending() >= swapThreshold;
        
        if (!_swapping && !AMMPairs[from] && canSwap) {
            _swapping = true;
            
            if (false || _buybackandlpPending > 0 || _revsharePending > 0 || _backendPending > 0) {
                uint256 token2Swap = 0 + _buybackandlpPending + _revsharePending + _backendPending;
                bool success = false;

                _swapTokensForCoin(token2Swap);
                uint256 coinsReceived = address(this).balance;
                
                uint256 buybackandlpPortion = coinsReceived * _buybackandlpPending / token2Swap;
                if (buybackandlpPortion > 0) {
                    success = payable(buybackandlpAddress).send(buybackandlpPortion);
                    if (success) {
                        emit buybackandlpFeeSent(buybackandlpAddress, buybackandlpPortion);
                    }
                }
                _buybackandlpPending = 0;

                uint256 revsharePortion = coinsReceived * _revsharePending / token2Swap;
                if (revsharePortion > 0) {
                    success = payable(revshareAddress).send(revsharePortion);
                    if (success) {
                        emit revshareFeeSent(revshareAddress, revsharePortion);
                    }
                }
                _revsharePending = 0;

                uint256 backendPortion = coinsReceived * _backendPending / token2Swap;
                if (backendPortion > 0) {
                    success = payable(backendAddress).send(backendPortion);
                    if (success) {
                        emit backendFeeSent(backendAddress, backendPortion);
                    }
                }
                _backendPending = 0;

            }

            _swapping = false;
        }

        if (!_swapping && amount > 0 && to != address(routerV2) && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            uint256 fees = 0;
            uint8 txType = 3;
            
            if (AMMPairs[from]) {
                if (totalFees[0] > 0) txType = 0;
            }
            else if (AMMPairs[to]) {
                if (totalFees[1] > 0) txType = 1;
            }
            else if (totalFees[2] > 0) txType = 2;
            
            if (txType < 3) {
                
                fees = amount * totalFees[txType] / 10000;
                amount -= fees;
                
                _buybackandlpPending += fees * buybackandlpFees[txType] / totalFees[txType];

                _revsharePending += fees * revshareFees[txType] / totalFees[txType];

                _backendPending += fees * backendFees[txType] / totalFees[txType];

                
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }
        }
        
        super._transfer(from, to, amount);
        
    }

    function _updateRouterV2(address router) private {
        routerV2 = IUniswapV2Router02(router);
        pairV2 = IUniswapV2Factory(routerV2.factory()).createPair(address(this), routerV2.WETH());
        
        _excludeFromLimits(router, true);

        _setAMMPair(pairV2, true);

        emit RouterV2Updated(router);
    }

    function setAMMPair(address pair, bool isPair) external onlyOwner {
        require(pair != pairV2, "DefaultRouter: Cannot remove initial pair from list");

        _setAMMPair(pair, isPair);
    }

    function _setAMMPair(address pair, bool isPair) private {
        AMMPairs[pair] = isPair;

        if (isPair) { 
            _excludeFromLimits(pair, true);

        }

        emit AMMPairsUpdated(pair, isPair);
    }

    function excludeFromLimits(address account, bool isExcluded) external onlyOwner {
        _excludeFromLimits(account, isExcluded);
    }

    function _excludeFromLimits(address account, bool isExcluded) internal {
        isExcludedFromLimits[account] = isExcluded;

        emit ExcludeFromLimits(account, isExcluded);
    }

    function updateMaxWalletAmount(uint256 _maxWalletAmount) public onlyOwner {
        require(_maxWalletAmount >= _maxWalletSafeLimit(), "MaxWallet: Limit too low");
        maxWalletAmount = _maxWalletAmount;
        
        emit MaxWalletAmountUpdated(_maxWalletAmount);
    }

    function _maxWalletSafeLimit() private view returns (uint256) {
        return totalSupply() / 1000;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        if (!isExcludedFromLimits[to]) {
            require(balanceOf(to) <= maxWalletAmount, "MaxWallet: Cannot exceed max wallet limit");
        }

        super._afterTokenTransfer(from, to, amount);
    }
}
