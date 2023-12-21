// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";
import "./IUniswapV2Router01.sol";
import "./PersonalEmbrVester.sol";
import "./PresaleManager.sol";
import "./SafeMath.sol";

contract EMBRToken is ERC20, Owned {
    using SafeMath for uint256;

    uint public buy_tax = 5;
    uint public sell_tax = 5;
    uint public preventSwapBefore = 10;
    uint public buyCount = 0;
    uint public swapThreshold = 100_000 * 10**18;
    uint public inSwap = 1; // 1 = false, 2 = true. Saves gas cuz changing from non zero to non zero is cheaper than changing zero to non zero.
    mapping(address => bool) public lps;
    mapping(address => bool) public routers;
    mapping(address => bool) public excludedFromFee;
    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uniRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    uint public maxTx = 1_000_000 * 10**18;
    uint public maxHolding = 1_000_000 * 10**18;

    uint public isTradingEnabled = 1;

    mapping(address => bool) public excludedAntiWhales;

    constructor() ERC20("Ember", "EMBR", 18) Owned(msg.sender) {
        excludedAntiWhales[address(this)] = true;
        excludedAntiWhales[msg.sender] = true;


        // uni router 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        routers[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true;
        allowance[address(this)][0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = type(uint256).max;
        excludedAntiWhales[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true;

        super._mint(msg.sender, 9_000_000 * 10**18);
    }

    modifier lockTheSwap() {
        inSwap = 2;
        _;
        inSwap = 1;
    }

    function setMaxTx(uint amount) onlyOwner external {
        maxTx = amount;
    }

    function setMaxHolding(uint amount) onlyOwner external {
        maxHolding = amount;
    }

    function excludeWhale(address addy) onlyOwner external {
        excludedAntiWhales[addy] = true;
    }

    function setUniRouter(address newRouter) onlyOwner external {
        uniRouter = newRouter;
    }

    function setAmm(address lp) onlyOwner external {
        lps[lp] = true;
        excludedAntiWhales[lp] = true;
    }

    function setRouter(address router) onlyOwner external {
        routers[router] = true;
        allowance[address(this)][router] = type(uint256).max;
        excludedAntiWhales[router] = true;
    }

    function excludeFromFee(address addy) onlyOwner external {
        excludedFromFee[addy] = true;
    }

    function setPreventSwapBefore(uint counter) onlyOwner external {
        preventSwapBefore = counter;
    }

    function setSwapThreshold(uint newThreshold) onlyOwner external {
        swapThreshold = newThreshold;
    }

    function setSellTax(uint newTax) onlyOwner external {
        sell_tax = newTax;
    }

    function setBuyTax(uint newTax) onlyOwner external {
        buy_tax = newTax;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(isTradingEnabled == 2 || tx.origin == owner, "trading isnt live");
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(maxTx >= amount || excludedAntiWhales[from], "max tx limit");

        uint256 taxAmount = 0;
        if (from != owner && to != owner && tx.origin != owner) {
            bool isSelling;
            if (lps[from] &&
                !routers[to] &&
                !excludedFromFee[to]) {
                    buyCount++;
                    taxAmount = amount
                    .mul(buy_tax)
                    .div(100);
            }

            if (lps[to] && from != address(this)) {
                isSelling = true;
                taxAmount = amount
                .mul(sell_tax)
                .div(100);
            }

            uint256 contractTokenBalance = balanceOf[address(this)];
            if (
                inSwap == 1 &&
                isSelling &&
                contractTokenBalance > swapThreshold &&
                buyCount > preventSwapBefore
            ) {
                swapTokensForEth(contractTokenBalance);
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0.1 ether) {
                    payable(owner).transfer(contractETHBalance);
                }
            }
        }

        if (taxAmount > 0) {
            balanceOf[address(this)] = balanceOf[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        }

        balanceOf[from] = balanceOf[from].sub(amount);
        balanceOf[to] = balanceOf[to].add(amount.sub(taxAmount));

        require(balanceOf[to] <= maxHolding || excludedAntiWhales[to] || tx.origin == owner, "max holding limit");
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function enableTrading() onlyOwner external {
        isTradingEnabled = 2;
    }

    function claimTaxes() onlyOwner external {
        uint256 contractTokenBalance = balanceOf[address(this)];
        balanceOf[address(this)] -= contractTokenBalance;
        balanceOf[owner] += contractTokenBalance;
        emit Transfer(address(this), owner, contractTokenBalance);
    }

    function swapTokensForEth(uint amount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = weth;
        IUniswapV2Router01(uniRouter).swapExactTokensForETHSupportingFeeOnTransferTokens(amount, 0, path, address(this), 99999999999999999999);
    }

    function mint(uint amount) onlyOwner external {
        super._mint(owner, amount);
    }

    receive() external payable { }

    function withdraw() onlyOwner external {
        (bool sent,) = owner.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }
}
