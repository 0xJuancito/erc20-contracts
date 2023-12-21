// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IWMTR {
    function withdraw(uint256 wad) external;
}

interface IEIP712 {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) external;
}
import "@openzeppelin/contracts/access/Ownable.sol";

contract PermitRouter is Ownable {
    using SafeERC20 for IERC20;
    // event
    event GaslessSwap(
        address indexed owner,
        uint256 amountIn,
        uint256 amountOut,
        uint256 deadline,
        bytes signature
    );

    address public immutable pair;
    uint256 public fee;
    address[] public path;
    IWMTR public constant wmtr =
        IWMTR(0x160361ce13ec33C993b5cCA8f62B6864943eb083);

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    receive() external payable {
        require(msg.sender == address(wmtr), "Router: NOT_WMTR");
    }

    constructor(
        address _pair,
        address _token0,
        address _token1,
        uint256 _fee
    ) {
        require(_pair != address(0), "pair is zero address");
        require(_token0 != address(0), "token0 is zero address");
        require(_token1 != address(0), "token1 is zero address");
        pair = _pair;
        path.push(_token0);
        path.push(_token1);
        fee = _fee;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address _to) internal virtual {
        (address input, address output) = (path[0], path[1]);
        (address _token0, ) = UniswapV2Library.sortTokens(input, output);
        uint256 amountOut = amounts[1];
        (uint256 amount0Out, uint256 amount1Out) = input == _token0
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, _to, new bytes(0));
    }

    function _handleFee(address to) internal {
        uint256 balance = IERC20(path[1]).balanceOf(address(this));
        wmtr.withdraw(balance);
        _safeTransferMTR(to, (balance * (10000 - fee)) / 10000);
        uint256 feeBalance = address(this).balance;
        _safeTransferMTR(msg.sender, feeBalance);
    }

    function swapExactTokensForTokens(
        address owner,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        bytes memory signature
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(pair, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IEIP712(path[0]).permit(
            owner,
            address(this),
            amountIn,
            deadline,
            signature
        );

        TransferHelper.safeTransferFrom(path[0], owner, pair, amounts[0]);
        _swap(amounts, address(this));
        _handleFee(owner);
        emit GaslessSwap(owner, amounts[0], amounts[1], deadline, signature);
    }

    function swapTokensForExactTokens(
        address owner,
        uint256 amountOut,
        uint256 amountInMax,
        uint256 deadline,
        bytes memory signature
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(pair, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        IEIP712(path[0]).permit(
            owner,
            address(this),
            amountInMax,
            deadline,
            signature
        );
        TransferHelper.safeTransferFrom(path[0], owner, pair, amounts[0]);
        _swap(amounts, address(this));
        _handleFee(owner);
        emit GaslessSwap(owner, amounts[0], amounts[1], deadline, signature);
    }

    function getAmountsOut(uint256 amountIn)
        external
        view
        returns (uint256[] memory amounts)
    {
        amounts = UniswapV2Library.getAmountsOut(pair, amountIn, path);
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint256 amountOut)
        external
        view
        returns (uint256[] memory amounts)
    {
        amounts = UniswapV2Library.getAmountsIn(pair, amountOut, path);
    }

    function _safeTransferMTR(address to, uint value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "VoltRouter: ETH_TRANSFER_FAILED");
    }
}

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

library UniswapV2Library {
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address pair,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator + 1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address pair,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(
                pair,
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address pair,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(
                pair,
                path[i - 1],
                path[i]
            );
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FROM_FAILED"
        );
    }
}
