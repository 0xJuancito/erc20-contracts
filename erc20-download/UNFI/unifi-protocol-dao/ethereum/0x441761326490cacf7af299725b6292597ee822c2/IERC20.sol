pragma solidity ^0.4.25;

/**
 * @title ERC20 interface 
 * @dev see https://github.com/binance-chain/ERCs/blob/master/ERC20.md#52-implementation
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
    external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value)
    external returns (bool);

    function transferFrom(address from, address to, uint256 value)
    external returns (bool);

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    event ProposalUpdated(address indexed owner,
                        uint256 proposalID,
                        bool result,
                        uint256 value);
}
