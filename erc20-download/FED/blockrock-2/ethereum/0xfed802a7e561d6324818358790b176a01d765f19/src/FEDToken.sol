// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";

contract FEDToken is ERC20, Ownable {
    struct TaxDecay {
        uint256 initialTax;
        uint256 decay;
        uint256 lastDecay;
    }

    // TOKENOMICS START ==========================================================>
    string private _name = "BlockRock";
    string private _symbol = "FED";
    uint8 private _decimals = 18;
    uint256 private _supply = 1e8 * 10 ** _decimals;
    uint256 public tax = 500; // 5%
    uint256 public treasuryPart;
    uint256 public operationPart;
    uint256 public taxThreshold;
    address payable public treasury;
    address payable public operation;
    uint256 public maxTxAmount = 1e6 * 10 ** _decimals;
    bool public tradingEnabled;
    TaxDecay public taxDecay;

    uint256 public constant BASE = 10_000;

    mapping(address => bool) public _isExcludedFromFee;

    // TOKENOMICS END ============================================================>

    event ExcludedFromFeeUpdated(address _address, bool _status);

    address public immutable uniswapPair;
    IUniswapV2Router02 public immutable uniswapRouter;

    bool swapAndLiquidity;

    error TaxTooHigh();
    error NotHundredPercent();
    error TradingNotEnabled();
    error TradingAlreadyEnabled();
    error TxExceedsMaxAmount();

    modifier lockTheSwap() {
        swapAndLiquidity = true;
        _;
        swapAndLiquidity = false;
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(address _owner) ERC20(_name, _symbol) Ownable(_owner) {
        uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(address(this), uniswapRouter.WETH());
        _mint(_owner, _supply);
        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[msg.sender] = true;
        treasuryPart = 7500;
        operationPart = 2500;
        taxThreshold = 50_000e18;
        treasury = payable(0xc6A5Ad039bfa0a36D5364FEC1A62c8199D30ea29);
        operation = payable(0x607eAcfe35cd2315F0477d257Fe7603A3a528BA5);
        _isExcludedFromFee[treasury] = true;
        _isExcludedFromFee[operation] = true;
    }

    function _decayTheTax() internal {
        uint256 currentTax = taxDecay.initialTax; //SSTORE
        if (currentTax == 0) return;
        uint256 decayAmount = (block.number - taxDecay.lastDecay) * taxDecay.decay;
        if (decayAmount >= currentTax) {
            taxDecay.initialTax = 0;
        } else {
            taxDecay.initialTax -= decayAmount;
        }
        taxDecay.lastDecay = block.number;
    }

    function enableTrading() external onlyOwner {
        if (tradingEnabled) revert TradingAlreadyEnabled();
        taxDecay = TaxDecay(4500, 4500 / 5, block.number);
        tradingEnabled = true;
    }

    function _update(address from, address to, uint256 amount) internal override {
        _decayTheTax();
        if ((from == uniswapPair || to == uniswapPair) && !swapAndLiquidity && tax > 0) {
            uint256 pendingTax = balanceOf(address(this));
            if (pendingTax >= taxThreshold && from != uniswapPair) {
                _sellTaxAndSend(pendingTax);
            }
            uint256 transferAmount;
            if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
                transferAmount = amount;
            } else {
                if (!tradingEnabled) revert TradingNotEnabled();
                uint256 totalTax = ((amount * (tax + taxDecay.initialTax)) / BASE);
                super._update(from, address(this), totalTax);
                transferAmount = amount - totalTax;
                if (transferAmount > maxTxAmount) revert TxExceedsMaxAmount();
            }
            super._update(from, to, transferAmount);
        } else {
            super._update(from, to, amount);
        }
    }

    function _sellTaxAndSend(uint256 pendingTax) internal {
        _swapTokensForEth(pendingTax);
        uint256 ethBalance = address(this).balance;
        uint256 treasuryAmount = (ethBalance * treasuryPart) / BASE;
        uint256 operationAmount = ethBalance - treasuryAmount;
        treasury.transfer(treasuryAmount);
        operation.transfer(operationAmount);
    }

    function _swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();

        _approve(address(this), address(uniswapRouter), tokenAmount);

        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, 0, path, address(this), block.timestamp
        );
    }

    function excludeFromFee(address _address, bool _status) external onlyOwner {
        _isExcludedFromFee[_address] = _status;
        emit ExcludedFromFeeUpdated(_address, _status);
    }

    function setTreasuryAddress(address payable _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function setOperationAddress(address payable _operation) external onlyOwner {
        operation = _operation;
    }

    function withdrawTax() external onlyOwner {
        uint256 pendingTax = balanceOf(address(this));
        _sellTaxAndSend(pendingTax);
    }

    receive() external payable { }
}