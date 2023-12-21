// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "bsc-library/contracts/ERC20.sol";
import "bsc-library/contracts/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "exchange-protocol/contracts/interfaces/IPancakePair.sol";
import "exchange-protocol/contracts/interfaces/IPancakeRouter02.sol";
import "exchange-protocol/contracts/interfaces/IPancakeFactory.sol";

contract TrustBitFinance is ERC20, ERC20Burnable, ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    uint256 public dexSellTaxFee = 1500;
    uint256 public dexBuyTaxFee = 0;
    address public taxAddress;
    address public immutable pairAddress;
    address public immutable routerAddress;
    mapping(address => bool) private _isExcludedFromFee;


    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor() ERC20("TrustBit.Finance", "TRS") {
        _mint(msg.sender, 20000000 * 10 ** decimals());

        taxAddress = payable(msg.sender);

        // IPancakeRouter02 _router = IPancakeRouter02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); // Testnet
        IPancakeRouter02 _router = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Mainnet

        pairAddress = IPancakeFactory(_router.factory()).createPair(address(this), _router.WETH());

        routerAddress = address(_router);

        _isExcludedFromFee[owner()] = true;
    }


    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setTaxAddress(address _taxAddress) public onlyOwner {
        taxAddress = _taxAddress;
    }

    function setTax(uint256 _sellTaxFee, uint256 _buyTaxFee) public onlyOwner {
        dexSellTaxFee = _sellTaxFee;
        dexBuyTaxFee = _buyTaxFee;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function amountForEth(uint256 ethAmount) public view returns (uint256 tokenAmount){
        address _token0Address = IPancakePair(pairAddress).token0();
        address wethAddress = IPancakeRouter02(routerAddress).WETH();

        (uint112 _reserve0,uint112 _reserve1,) = IPancakePair(pairAddress).getReserves();
        uint256 _tokenAmount;
        uint256 _wethAmount;
        if (_token0Address == wethAddress) {
            _wethAmount = _reserve0;
            _tokenAmount = _reserve1;
        }
        else {
            _wethAmount = _reserve1;
            _tokenAmount = _reserve0;
        }
        tokenAmount = ethAmount.mul(_tokenAmount).div(_wethAmount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20)
    {
        super._burn(account, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = balanceOf(sender);
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            _configBalanceOf(sender, senderBalance.sub(amount));
        }

        bool takeFee = true;
        if (_isExcludedFromFee[sender]) {
            takeFee = false;
        }

        if (sender == pairAddress && takeFee) {
            uint256 taxFee = amount.mul(dexBuyTaxFee).div(10000);
            _configBalanceOf(taxAddress, balanceOf(taxAddress).add(taxFee));
            emit Transfer(sender, taxAddress, taxFee);
            amount = amount.sub(taxFee);
        }

        if (recipient == pairAddress && takeFee) {
            uint256 taxFee = amount.mul(dexSellTaxFee).div(10000);
            _configBalanceOf(taxAddress, balanceOf(taxAddress).add(taxFee));
            emit Transfer(sender, taxAddress, taxFee);
            amount = amount.sub(taxFee);
        }

        _configBalanceOf(recipient, balanceOf(recipient).add(amount));

        emit Transfer(sender, recipient, amount);
    }
}
