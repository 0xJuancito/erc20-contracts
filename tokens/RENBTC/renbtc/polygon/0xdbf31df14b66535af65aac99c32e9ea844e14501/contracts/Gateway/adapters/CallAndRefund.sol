pragma solidity ^0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "./GenericAdapter.sol";

interface UniswapRouter {
    function WETH() external returns (address);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract CallAndRefund {
    GenericAdapter public genericAdapter;
    UniswapRouter public uniswapRouter;
    IGatewayRegistry public registry;

    constructor(
        IGatewayRegistry _registry,
        GenericAdapter _genericAdapter,
        UniswapRouter _uniswapRouter
    ) public {
        registry = _registry;
        genericAdapter = _genericAdapter;
        uniswapRouter = _uniswapRouter;
    }

    modifier withGasRefund() {
        uint256 remainingGasStart = gasleft();

        _;

        uint256 ethBalance = address(this).balance;
        uint256 remainingGasEnd = gasleft();
        uint256 usedGas = remainingGasStart - remainingGasEnd;
        // Add intrinsic gas and transfer gas. Need to account for gas stipend as well.
        usedGas += 21000 + 9700;
        // Possibly need to check max gasprice and usedGas here to limit possibility for abuse.
        uint256 gasCost = usedGas * tx.gasprice;
        require(ethBalance >= gasCost, "GaslessWithUniswap: gas exceeds fee");
        // Refund gas cost
        msg.sender.transfer(ethBalance);
    }

    // Allow this contract to receive ETH.
    function receive() external payable {}

    function convertAllToEth(IERC20 token) public payable {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = uniswapRouter.WETH();

        uint256 tokenBalance = token.balanceOf(address(this));
        token.approve(address(uniswapRouter), tokenBalance);
        uniswapRouter.swapExactTokensForETH(
            tokenBalance,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function callAndRefund(
        IERC20 _token,
        address _contract,
        bytes calldata _contractParams
    ) external withGasRefund {
        arbitraryCall(_contract, _contractParams);
        convertAllToEth(_token);
    }

    function arbitraryCall(address _contract, bytes memory _contractParams)
        internal
    {
        (bool success, bytes memory result) = _contract.call(_contractParams);
        if (!success) {
            // Check if the call result was too short to be a revert reason.
            if (result.length < 68) {
                revert(
                    "GenericAdapter: contract call failed without revert reason"
                );
            }
            // Return the call's revert reason.
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
    }
}
