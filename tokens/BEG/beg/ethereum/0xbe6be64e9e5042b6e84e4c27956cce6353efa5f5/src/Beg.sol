// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

// 01000010 01000101 01000111 00100000 01000010 01001001 01010100 01000011 01001000 00100001

import {Ownable} from "./Ownable.sol";
import {SafeERC20} from "./SafeERC20.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

contract Beg is Ownable {
    string public constant name = "Beg";
    string public constant symbol = "BEG";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 525_600 ether;

    address private constant LP_TOKEN_RECIPIENT = 0x588A03B23849E5Bc5C451C6fc696797c608a48e0;
    address private constant AIRDROPPER = 0x9a8F6EEF34A4A30763e6eA6e43cDFfdb4913fD36;
    address public treasuryWallet = 0x91364516D3CAD16E1666261dbdbb39c881Dbe9eE;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint8 public constant MAX_BUY_FEES = 100;
    uint8 public constant MAX_SELL_FEES = 100;
    uint8 public constant TRADING_DISABLED = 0;
    uint8 public constant TRADING_ENABLED = 1;
    uint8 public buyTotalFees = 20;
    uint8 public sellTotalFees = 20;
    uint8 public tradingStatus = TRADING_DISABLED;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _allowedDuringPause;
    mapping(address => bool) private automatedMarketMakerPairs;
    mapping(address => uint256) public begged;

    IUniswapV2Router02 public constant uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public immutable uniswapV2Pair;

    error ZeroAddress();
    error InsufficientAllowance();
    error InsufficientBalance();
    error CannotRemoveV2Pair();
    error WithdrawalFailed();
    error InvalidState();
    error FeesExceedMax();
    error TradingDisabled();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() Ownable(LP_TOKEN_RECIPIENT) payable {
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), WETH);
        automatedMarketMakerPairs[uniswapV2Pair] = true;

        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[treasuryWallet] = true;
        _allowedDuringPause[AIRDROPPER] = true;

        uint256 begToLP = totalSupply * 25 / 100;
        uint256 begToAirdrop = totalSupply - begToLP;

        _balances[AIRDROPPER] = begToAirdrop;
        emit Transfer(address(0), AIRDROPPER, begToAirdrop);
        _balances[address(this)] = begToLP;
        emit Transfer(address(0), address(this), begToLP);

        _approve(address(this), address(uniswapV2Router), type(uint256).max);
    }

    function startBegging(uint256 begPerETH) external payable onlyOwner {
        uint256 ethToLP = address(this).balance;
        uint256 begToLP = begPerETH * address(this).balance;
        uint256 begBalance = _balances[address(this)];
        if(begToLP > begBalance) {
            begToLP = begBalance;
            ethToLP = begToLP / begPerETH;
        }
        uniswapV2Router.addLiquidityETH{value: ethToLP}(
            address(this),
            begToLP,
            0,
            0,
            LP_TOKEN_RECIPIENT,
            block.timestamp
        );
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        if(owner == address(0)) revert ZeroAddress();
        if(spender == address(0)) revert ZeroAddress();

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if(currentAllowance < amount) revert InsufficientAllowance();
            unchecked {
                _approve(sender, msg.sender, currentAllowance - amount);
            }
        }

        _transfer(sender, recipient, amount);

        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        if(from == address(0)) revert ZeroAddress();
        if(to == address(0)) revert ZeroAddress();

        if(tradingStatus == TRADING_DISABLED) {
            if(from != owner() && from != treasuryWallet && from != address(this) && to != owner()) {
                if(!_allowedDuringPause[from]) {
                    revert TradingDisabled();
                }
            }
        }

        bool takeFee = true;
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 senderBalance = _balances[from];
        if(senderBalance < amount) revert InsufficientBalance();

        uint256 fees = 0;
        if (takeFee) {
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = (amount * sellTotalFees) / 1000;
            } else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = (amount * buyTotalFees) / 1000;
            }

            if (fees > 0) {
                unchecked {
                    amount = amount - fees;
                    _balances[from] -= fees;
                    _balances[treasuryWallet] += fees;
                }
                emit Transfer(from, treasuryWallet, fees);
            }
        }
        unchecked {
            _balances[from] -= amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function setFees(uint8 _buyTotalFees, uint8 _sellTotalFees) external onlyOwner {
        if(_buyTotalFees > MAX_BUY_FEES || _sellTotalFees > MAX_SELL_FEES) revert FeesExceedMax();
        buyTotalFees = _buyTotalFees;
        sellTotalFees = _sellTotalFees;
    }

    function setExcludedFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function setAllowedDuringPause(address account, bool allowed) public onlyOwner {
        _allowedDuringPause[account] = allowed;
    }

    function enableTrading() public onlyOwner {
        tradingStatus = TRADING_ENABLED;
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        if(pair == uniswapV2Pair) revert CannotRemoveV2Pair();
        automatedMarketMakerPairs[pair] = value;
    }

    function updateTreasuryWallet(address newAddress) external onlyOwner {
        if(newAddress == address(0)) revert ZeroAddress();
        treasuryWallet = newAddress;
    }

    function excludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawToken(address token, address to) external onlyOwner {
        uint256 _contractBalance = IERC20(token).balanceOf(address(this));
        SafeERC20.safeTransfer(token, to, _contractBalance); // Use safeTransfer
    }

    function withdrawETH(address addr) external onlyOwner {
        if(addr == address(0)) revert ZeroAddress();

        (bool success, ) = addr.call{value: address(this).balance}("");
        if(!success) revert WithdrawalFailed();
    }

    function beg() external {
        unchecked {
            ++begged[msg.sender];
        }
    }
}