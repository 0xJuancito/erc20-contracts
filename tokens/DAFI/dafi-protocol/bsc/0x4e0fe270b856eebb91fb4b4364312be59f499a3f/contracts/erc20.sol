pragma solidity 0.8.9;
import "./erc20basic.sol";


 interface ERC20 is ERC20Basic {
    function allowance(address owner, address spender) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}