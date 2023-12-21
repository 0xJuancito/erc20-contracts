//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

interface IRun {
    event TransferWithMemo(address indexed from, address indexed to, uint256 value, string[] memo);

    function transferWithMemo(address to, uint256 amount, string[] memory memo) external;

    function transferFromWithMemo(address from, address to, uint256 amount, string[] memory memo) external;
}
