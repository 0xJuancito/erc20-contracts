// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IWMTR {
    function withdraw(uint256 wad) external;
}

interface Pair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getAmountOut(uint256 amountIn, address tokenIn)
        external
        view
        returns (uint256);

    function skim(address to) external;

    function metadata()
        external
        view
        returns (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,
            address t1
        );

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

interface IEIP712 {
    function permit(
        address _owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) external;
}
import "@openzeppelin/contracts/access/Ownable.sol";

contract PermitRouterV2 is Ownable {
    using SafeERC20 for IERC20;

    uint256 public fee;
    address[] public path;
    address public tokenIn;
    IWMTR public immutable wmtr;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    receive() external payable {
        require(msg.sender == address(wmtr), "Router: NOT_WMTR");
    }

    constructor(
        uint256 _fee,
        address _tokenIn,
        IWMTR _wmtr,
        address[] memory _path
    ) {
        path = _path;
        fee = _fee;
        tokenIn = _tokenIn;
        wmtr = _wmtr;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function _handleFee(uint256 balance, address to) internal {
        wmtr.withdraw(balance);
        _safeTransferMTR(to, (balance * (10000 - fee)) / 10000);
        uint256 feeBalance = address(this).balance;
        _safeTransferMTR(msg.sender, feeBalance);
    }

    function swapExactTokensForTokens(
        address _owner,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        bytes memory signature
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        IEIP712(tokenIn).permit(
            _owner,
            address(this),
            amountIn,
            deadline,
            signature
        );

        TransferHelper.safeTransferFrom(tokenIn, _owner, path[0], amountIn);

        amounts = new uint256[](path.length + 1);
        amounts[0] = amountIn;
        address currentToken = tokenIn;
        for (uint256 i = 0; i < path.length; ++i) {
            address _pair = path[i];
            address token0 = Pair(_pair).token0();
            address token1 = Pair(_pair).token1();
            uint256 amountOut = Pair(_pair).getAmountOut(
                amounts[i],
                currentToken
            );
            (uint256 amountOut0, uint256 amountOut1) = currentToken == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i == path.length - 1 ? address(this) : path[i + 1];
            Pair(_pair).swap(amountOut0, amountOut1, to, new bytes(0));
            amounts[i + 1] = amountOut;
            currentToken = currentToken == token0 ? token1 : token0;
        }
        uint256 balance = IERC20(address(wmtr)).balanceOf(address(this));
        require(
            balance >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        _handleFee(balance, _owner);
    }

    function getAmountsOut(uint256 amountIn)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory amounts = new uint256[](path.length + 1);
        amounts[0] = amountIn;
        address currentToken = tokenIn;
        for (uint256 i = 0; i < path.length; ++i) {
            address _pair = path[i];
            address token0 = Pair(_pair).token0();
            address token1 = Pair(_pair).token1();
            uint256 amountOut = Pair(_pair).getAmountOut(
                amounts[i],
                currentToken
            );
            amounts[i + 1] = amountOut;
            currentToken = currentToken == token0 ? token1 : token0;
        }
        return amounts;
    }

    function _safeTransferMTR(address to, uint value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "VoltRouter: ETH_TRANSFER_FAILED");
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
