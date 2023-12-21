// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "./ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title EQ9 Token(EQ9)
 * @author Pedro Henrique Bufulin de Almeida
 * @notice Implements a basic ERC20 utility & staking token.
 */
contract EQ9 is ERC20 {
    using Counters for Counters.Counter;
    Counters.Counter private stakesAmount;

    constructor() ERC20("EQ9", "EQ9") {
        _mint(msg.sender, 18 * 10**8 * (10**decimals()));
    }

    /**
     * @notice The stakers for each stakeholder.
     */
    mapping(address => uint256) public stakers;

    /**
     * @notice A method for a stakeholder to create a stake.
     * @param _stake The size of the stake to be created.
     */
    function stake(uint256 _stake) external {
        if (stakers[msg.sender] == 0) stakesAmount.increment();
        stakers[msg.sender] += _stake;
        _burn(msg.sender, _stake);
    }

    /**
     * @notice A method for a stakeholder to create a stake.
     * @param _stake Amount of tokens to unstake.
     */
    function unstake(uint256 _stake) external {
        stakers[msg.sender] -= _stake;
        if (stakers[msg.sender] == 0) stakesAmount.decrement();
        _mint(msg.sender, _stake);
    }

    /**
     * @notice Verifies the amount of individual stakes.
     */
    function amountStakes() public view returns (uint256) {
        return stakesAmount.current();
    }
}
