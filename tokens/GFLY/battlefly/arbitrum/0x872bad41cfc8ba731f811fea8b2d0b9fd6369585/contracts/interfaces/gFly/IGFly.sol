// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGFly is IERC20 {
    function MAX_SUPPLY() external returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}
