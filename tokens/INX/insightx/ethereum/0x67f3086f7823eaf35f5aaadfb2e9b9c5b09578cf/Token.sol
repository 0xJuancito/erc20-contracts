/*
TG: https://t.me/InsightxNetwork
Website: https://insightx.network/
Twitter: https://twitter.com/InsightXnetwork

TAX
BUY and SEll tax 4%
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

contract InsightX is ERC20, ERC20Burnable, Ownable, Initializable {
    
    address public taxAddress;
    uint16[3] public taxFees;

    mapping (address => bool) public isExcludedFromFees;

    uint16[3] public totalFees;
    bool private _swapping;

    IUniswapV2Router02 public routerV2;
    address public pairV2;
    mapping (address => bool) public AMMPairs;
 
    event taxAddressUpdated(address taxAddress);
    event taxFeesUpdated(uint16 buyFee, uint16 sellFee, uint16 transferFee);
    event taxFeeSent(address recipient, uint256 amount);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event RouterV2Updated(address indexed routerV2);
    event AMMPairsUpdated(address indexed AMMPair, bool isPair);
 
    constructor()
        ERC20(unicode"InsightX", unicode"INX") 
    {
        address supplyRecipient = 0xC147F6835c20a0b48a3eeCAE829C678E6e081123;
        
        taxAddressSetup(0x6946fD49d61929E02dCF2F938cFC2C66D5f317b6);
        taxFeesSetup(400, 400, 0);

        excludeFromFees(supplyRecipient, true);
        excludeFromFees(address(this), true); 

        _mint(supplyRecipient, 2500000000 * (10 ** decimals()) / 10);
        _transferOwnership(0xC147F6835c20a0b48a3eeCAE829C678E6e081123);
    }
    
    function initialize(address _router) initializer external {
        _updateRouterV2(_router);
    }

    receive() external payable {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    function _sendInTokens(address from, address to, uint256 amount) private {
        super._transfer(from, to, amount);
    }

    function taxAddressSetup(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "TaxesDefaultRouterWallet: Wallet tax recipient cannot be a 0x0 address");

        taxAddress = _newAddress;
        excludeFromFees(_newAddress, true);

        emit taxAddressUpdated(_newAddress);
    }

    function taxFeesSetup(uint16 _buyFee, uint16 _sellFee, uint16 _transferFee) public onlyOwner {
        totalFees[0] = totalFees[0] - taxFees[0] + _buyFee;
        totalFees[1] = totalFees[1] - taxFees[1] + _sellFee;
        totalFees[2] = totalFees[2] - taxFees[2] + _transferFee;
        require(totalFees[0] <= 2500 && totalFees[1] <= 2500 && totalFees[2] <= 2500, "TaxesDefaultRouter: Cannot exceed max total fee of 25%");

        taxFees = [_buyFee, _sellFee, _transferFee];

        emit taxFeesUpdated(_buyFee, _sellFee, _transferFee);
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
                
                uint256 taxPortion = 0;

                fees = amount * totalFees[txType] / 10000;
                amount -= fees;
                
                if (taxFees[txType] > 0) {
                    taxPortion = fees * taxFees[txType] / totalFees[txType];
                    _sendInTokens(from, taxAddress, taxPortion);
                    emit taxFeeSent(taxAddress, taxPortion);
                }

                fees = fees - taxPortion;
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
        }

        emit AMMPairsUpdated(pair, isPair);
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
        super._afterTokenTransfer(from, to, amount);
    }
}
