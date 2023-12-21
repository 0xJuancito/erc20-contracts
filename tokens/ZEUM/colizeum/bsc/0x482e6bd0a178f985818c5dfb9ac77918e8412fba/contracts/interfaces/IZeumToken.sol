// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IZeumToken {
    function mint(address to, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function setSoftCap(uint256 newSoftCap) external;

    function getSoftCap() external returns (uint256);
}
