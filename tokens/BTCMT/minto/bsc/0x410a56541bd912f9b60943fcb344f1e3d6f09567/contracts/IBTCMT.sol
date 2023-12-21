// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBTCMT is IERC20 {

    event FarmStatusChanged (address indexed farm, bool isFarmNow);

    event TransferLocked (address indexed from, address indexed to, uint256 amount);

    event ApprovalLocked (address indexed owner, address indexed spender, uint256 amount);

    function balanceOfSum (address account) external view returns (uint256);

    function transferFarm (address to, uint256 amountLocked, uint256 amountUnlocked, uint256[] calldata farmIndexes) external returns (uint256[] memory);

    function transferFromFarm (address from, uint256 amountLocked, uint256 amountUnlocked) external returns (uint256[] memory);
}