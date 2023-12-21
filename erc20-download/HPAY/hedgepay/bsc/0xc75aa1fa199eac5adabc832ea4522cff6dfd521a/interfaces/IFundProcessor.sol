// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IFundProcessor {
    function processFunds(IERC20 token, uint256 amount) external;
}
