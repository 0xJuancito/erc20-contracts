// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC20PresetMinterPauser} from '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol';

import {Babylonian} from '../libraries/Babylonian.sol';

import {IUniswapV2Pair} from '../interfaces/IUniswapV2Pair.sol';
import {IUniswapV2Factory} from '../interfaces/IUniswapV2Factory.sol';
import {IUniswapV2Router02} from '../interfaces/IUniswapV2Router02.sol';
import {IRewardRecipient} from '../interfaces/IRewardRecipient.sol';

error INVALID_ADDRESS();
error INVALID_FEE();
error PAUSED();

contract Shezmu is ERC20PresetMinterPauser {
    using SafeERC20 for IERC20;

    /// @dev name
    string private constant NAME = 'Shezmu';

    /// @dev symbol
    string private constant SYMBOL = 'SHEZMU';

    /// @dev initial supply
    uint256 private constant INITIAL_SUPPLY = 10000000 ether;

    /// @notice percent multiplier (100%)
    uint256 public constant MULTIPLIER = 10000;

    /// @notice Uniswap Router
    IUniswapV2Router02 public immutable ROUTER;

    /// @notice tax info
    struct TaxInfo {
        uint256 guardianFee;
        uint256 liquidityFee;
        uint256 marketingFee;
    }
    TaxInfo public taxInfo;
    uint256 public totalFee;
    uint256 public uniswapFee;

    /// @notice guardian
    address public guardianFeeReceiver;

    /// @notice liquidity wallet
    address public liquidityFeeReceiver;

    /// @notice marketing wallet
    address public marketingFeeReceiver;

    /// @notice whether a wallet excludes fees
    mapping(address => bool) public isExcludedFromFee;

    /// @notice pending tax
    uint256 public pendingTax;

    /// @notice swap enabled
    bool public swapEnabled = true;

    /// @notice swap threshold
    uint256 public swapThreshold = INITIAL_SUPPLY / 20000; // 0.005%

    /// @dev in swap
    bool private inSwap;

    /* ======== EVENTS ======== */

    event GuardianFeeReceiver(address receiver);
    event LiquidityFeeReceiver(address receiver);
    event MarketingFeeReceiver(address receiver);
    event TaxFee(
        uint256 guardianFee,
        uint256 liquidityFee,
        uint256 marketingFee
    );
    event UniswapFee(uint256 uniswapFee);
    event ExcludeFromFee(address account);
    event IncludeFromFee(address account);

    /* ======== INITIALIZATION ======== */

    constructor(
        IUniswapV2Router02 router
    ) ERC20PresetMinterPauser(NAME, SYMBOL) {
        _mint(_msgSender(), INITIAL_SUPPLY);

        ROUTER = router;
        _approve(address(this), address(ROUTER), type(uint256).max);

        taxInfo.guardianFee = 200; // 2%
        taxInfo.liquidityFee = 200; // 2%
        taxInfo.marketingFee = 200; // 2%
        totalFee = 600; // 6%
        uniswapFee = 3; // 0.3% (1000 = 100%)

        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[address(this)] = true;
    }

    receive() external payable {}

    /* ======== MODIFIERS ======== */

    modifier onlyOwner() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    modifier swapping() {
        inSwap = true;

        _;

        inSwap = false;
    }

    /* ======== POLICY FUNCTIONS ======== */

    function setGuardianFeeReceiver(address receiver) external onlyOwner {
        if (receiver == address(0)) revert INVALID_ADDRESS();

        guardianFeeReceiver = receiver;

        emit GuardianFeeReceiver(receiver);
    }

    function setLiquidityFeeReceiver(address receiver) external onlyOwner {
        if (receiver == address(0)) revert INVALID_ADDRESS();

        liquidityFeeReceiver = receiver;

        emit LiquidityFeeReceiver(receiver);
    }

    function setMarketingFeeReceiver(address receiver) external onlyOwner {
        if (receiver == address(0)) revert INVALID_ADDRESS();

        marketingFeeReceiver = receiver;

        emit MarketingFeeReceiver(receiver);
    }

    function setTaxFee(
        uint256 guardianFee,
        uint256 liquidityFee,
        uint256 marketingFee
    ) external onlyOwner {
        totalFee = guardianFee + liquidityFee + marketingFee;
        if (totalFee == 0 || totalFee >= MULTIPLIER) revert INVALID_FEE();

        taxInfo.guardianFee = guardianFee;
        taxInfo.liquidityFee = liquidityFee;
        taxInfo.marketingFee = marketingFee;

        emit TaxFee(guardianFee, liquidityFee, marketingFee);
    }

    function setUniswapFee(uint256 fee) external onlyOwner {
        uniswapFee = fee;

        emit UniswapFee(fee);
    }

    function excludeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = true;

        emit ExcludeFromFee(account);
    }

    function includeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = false;

        emit IncludeFromFee(account);
    }

    function setSwapTaxSettings(
        bool enabled,
        uint256 threshold
    ) external onlyOwner {
        swapEnabled = enabled;
        swapThreshold = threshold;
    }

    function recoverERC20(IERC20 token) external onlyOwner {
        if (address(token) == address(this)) {
            token.safeTransfer(
                _msgSender(),
                token.balanceOf(address(this)) - pendingTax
            );
        } else {
            token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
        }
    }

    /* ======== PUBLIC FUNCTIONS ======== */

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        address owner = _msgSender();
        _transferWithTax(owner, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithTax(from, to, amount);
        return true;
    }

    /* ======== INTERNAL FUNCTIONS ======== */

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (from != address(0) && paused()) revert PAUSED();
    }

    function _getPoolToken(
        address pool,
        string memory signature,
        function() external view returns (address) getter
    ) internal returns (address) {
        (bool success, ) = pool.call(abi.encodeWithSignature(signature));

        if (success) {
            uint32 size;
            assembly {
                size := extcodesize(pool)
            }
            if (size > 0) {
                return getter();
            }
        }

        return address(0);
    }

    function _shouldTakeTax(address from, address to) internal returns (bool) {
        if (isExcludedFromFee[from] || isExcludedFromFee[to]) return false;

        address token0 = _getPoolToken(
            to,
            'token0()',
            IUniswapV2Pair(to).token0
        );
        address token1 = _getPoolToken(
            to,
            'token1()',
            IUniswapV2Pair(to).token1
        );

        return token0 == address(this) || token1 == address(this);
    }

    function _shouldSwapTax() internal view returns (bool) {
        return !inSwap && swapEnabled && pendingTax >= swapThreshold;
    }

    function _swapTax() internal swapping {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = ROUTER.WETH();

        uint256 balance = pendingTax;
        uint256 liquidityAmount = (balance * taxInfo.liquidityFee) / totalFee;

        delete pendingTax;

        // distribute tax (guardian, marketing)
        {
            uint256 swapAmount = balance - liquidityAmount;
            uint256 balanceBefore = address(this).balance;

            ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
                swapAmount,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 amountETH = address(this).balance - balanceBefore;
            uint256 guardianETH = (amountETH * taxInfo.guardianFee) /
                (taxInfo.guardianFee + taxInfo.marketingFee);
            uint256 marketingETH = amountETH - guardianETH;

            try
                IRewardRecipient(guardianFeeReceiver).receiveReward{
                    value: guardianETH
                }()
            {} catch {}

            payable(marketingFeeReceiver).call{value: marketingETH}('');
        }

        // add liquidity
        {
            IUniswapV2Pair pair = IUniswapV2Pair(
                IUniswapV2Factory(ROUTER.factory()).getPair(
                    address(this),
                    ROUTER.WETH()
                )
            );

            (uint256 rsv0, uint256 rsv1, ) = pair.getReserves();
            uint256 sellAmount = _calculateSwapInAmount(
                pair.token0() == address(this) ? rsv0 : rsv1,
                liquidityAmount
            );

            ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
                sellAmount,
                0,
                path,
                address(this),
                block.timestamp
            );
            ROUTER.addLiquidityETH{value: address(this).balance}(
                address(this),
                liquidityAmount - sellAmount,
                0,
                0,
                liquidityFeeReceiver,
                block.timestamp
            );
        }
    }

    function _calculateSwapInAmount(
        uint256 reserveIn,
        uint256 userIn
    ) internal view returns (uint256) {
        return
            (Babylonian.sqrt(
                reserveIn *
                    ((userIn * (uint256(4000) - (4 * uniswapFee)) * 1000) +
                        (reserveIn *
                            ((uint256(4000) - (4 * uniswapFee)) *
                                1000 +
                                uniswapFee *
                                uniswapFee)))
            ) - (reserveIn * (2000 - uniswapFee))) / (2000 - 2 * uniswapFee);
    }

    function _transferWithTax(
        address from,
        address to,
        uint256 amount
    ) internal {
        if (inSwap) {
            _transfer(from, to, amount);
            return;
        }

        if (_shouldTakeTax(from, to)) {
            uint256 tax = (amount * totalFee) / MULTIPLIER;
            unchecked {
                amount -= tax;
                pendingTax += tax;
            }
            _transfer(from, address(this), tax);
        }

        if (_shouldSwapTax()) {
            _swapTax();
        }

        _transfer(from, to, amount);
    }
}
