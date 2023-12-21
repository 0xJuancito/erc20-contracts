// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGENESIS is IERC20 {
    function mintToAddress(address user, uint256 amount) external;

    function governanceTransfer(
        address from,
        address to,
        uint256 amount
    ) external;
}
