pragma solidity ^0.6.0;

interface IMVDWallet {

    function getProxy() external view returns (address);

    function setProxy() external;

    function setNewWallet(address payable newWallet, address tokenAddress) external;

    function transfer(address receiver, uint256 value, address tokenAddress) external;
    
    function transfer(address receiver, uint256 tokenId, bytes calldata data, bool safe, address token) external;

    function flushToNewWallet(address token) external;

    function flush721ToNewWallet(uint256 tokenId, bytes calldata data, bool safe, address tokenAddress) external;
}