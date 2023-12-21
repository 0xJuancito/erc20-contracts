pragma solidity ^0.6.0;

interface IOracle {
    function update() external;

    function consult(address token, uint256 amountIn) external view returns (uint144 amountOut);

    function twap(address token, uint256 amountIn) external view returns (uint144 amountOut);
}
