// SPDX-License-Identifier: MIT
/* solhint-disable */

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

pragma solidity ^0.8.20;

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract HodlessBotToken is Initializable, ERC20Upgradeable, ERC20PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable  {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 private _maxAmountInOnWallet;
    uint32 private _feeRate;

    address public _routerAddress;
    mapping(address => bool) private _isBot;
    address[] private _botList;
    bool private  _tradingOpen;

    IUniswapV2Router02 private _uniswapV2Router;

    uint256 public  _launchTime;
    address public _developerAddress;

    address private _uniswapV2Pair;
    bool private _swapEnabled;

    uint256 public _maxSwapAmount;
    address public _swapPathTo;

    mapping(address => bool) _whitelist;

    function initialize() initializer public {
        __ERC20_init("Hodless BOT", "HBOT");
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("HB");

        _developerAddress = _msgSender();
        _swapEnabled = false;
        _maxAmountInOnWallet = 250_000 * 10**18;
        _feeRate = 4;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());

        _mint(address(this), 9_500_000 * 10**18);
        _mint(0x080E4DD0671f99Dc306C744cBf97F1e3f46DdC5a, 500_000 * 10**18);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        if (to != address(this) && to != _developerAddress && to !=_routerAddress && to != address(_uniswapV2Pair)) {
            bool isTaxFree = _whitelist[from] || _whitelist[to];
            if (_swapEnabled && !isTaxFree) {
                require(balanceOf(to) + value <= _maxAmountInOnWallet, "Update: Maximum balance for one wallet");
            }
        }

        super._update(from, to, value);
    }

    function beDominator() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!_tradingOpen, "beDominator: Trading is already open");
        _uniswapV2Router = IUniswapV2Router02(_routerAddress);
        _approve(address(this), address(_uniswapV2Router), type(uint).max);
        _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        _uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this), balanceOf(address(this)), 0, 0, _msgSender(), block.timestamp);

        IERC20(_uniswapV2Pair).approve(address(_uniswapV2Router), type(uint).max);

        _swapEnabled = true;
        _tradingOpen = true;
        _launchTime = block.timestamp;
    }

    function withdrawalEth(address to_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(to_).transfer(address(this).balance);
    }

    function withdrawalToken(address to_, address tokenAddress_ ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20 token = IERC20(tokenAddress_);
        uint256 balance = token.balanceOf(address(this));

        uint256 allowance = token.allowance(address(this), _msgSender());
        if (allowance < balance) {
            token.approve(_msgSender(), type(uint256).max);
        }

        token.transfer(to_, balance);
    }

    function setRouterAddress(address routerAddress_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _routerAddress = routerAddress_;
        approve(_routerAddress, type(uint256).max);
    }

    function setMaxSwapAmount(uint256 maxSwapAmount_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _maxSwapAmount = maxSwapAmount_;
    }

    function setSwapPath(address to_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _swapPathTo = to_;
    }

    function whitelist(address who, bool isTaxFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _whitelist[who] = isTaxFee;
    }

    receive() external payable {}

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transferToken(owner, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferToken(from, to, amount);
        return true;
    }

    function _transferToken(address from, address to, uint256 amount) internal {
        bool isTaxFree = _whitelist[from] || _whitelist[to];

        if (
            _swapEnabled &&
            ((from == _uniswapV2Pair || to == _uniswapV2Pair)) &&
            from != _developerAddress &&
            from != address(this) &&
            !isTaxFree
        ) {
            uint256 feeAmount = amount * _feeRate / 100;
            _transfer(from, address(this), feeAmount);
            _tokenTransferWithFee(from, to, amount);
        } else {
            _transfer(from, to, amount);
        }
    }

    function _tokenTransferWithFee(address from, address to, uint256 amount) private {
        uint256 feeAmount = amount * _feeRate / 100;
        uint256 targetAmount = amount - feeAmount;

        uint256 currentBalance = balanceOf(address(this));
        if (to == _uniswapV2Pair && currentBalance > 1) {
            uint256 maxSwapByAmount = amount / 100 * 15;
            uint256 swapAmount = maxSwapByAmount > currentBalance ? currentBalance - 1 : maxSwapByAmount;
            uint256 finalSwapAmount = swapAmount > _maxSwapAmount ? _maxSwapAmount : swapAmount;
            address[] memory swapPath = new address[](2);
            swapPath[0] = address(this);
            swapPath[1] = _swapPathTo;
            _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(finalSwapAmount, 0, swapPath, _developerAddress, block.timestamp + 1200);
        }

        _transfer(from, to, targetAmount);
    }
}
