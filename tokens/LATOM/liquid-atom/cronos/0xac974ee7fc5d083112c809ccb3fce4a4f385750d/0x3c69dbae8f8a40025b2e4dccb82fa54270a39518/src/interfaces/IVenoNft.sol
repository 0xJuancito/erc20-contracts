// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IVenoNft {
    function mint(address to) external returns (uint256);

    function burn(uint256 tokenId) external;

    function isApprovedOrOwner(address spender, uint256 tokenId) external returns (bool);
}
