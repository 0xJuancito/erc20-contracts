pragma solidity ^0.6.0;

interface IVotingToken {
    function init(string calldata name, string calldata symbol, uint256 decimals, uint256 totalSupply) external;

    function getProxy() external view returns (address);
    function setProxy() external;

    function name() external view returns(string memory);
    function symbol() external view returns(string memory);
    function decimals() external view returns(uint256);

    function mint(uint256 amount) external;
    function burn(uint256 amount) external;

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
}