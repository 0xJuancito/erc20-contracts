// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {FiatTokenV2_1} from "../v2/FiatTokenV2_1.sol";

/**
 * @title FiatToken V2.1.1
 * @notice ERC20 Token backed by fiat reserves
 */

contract FiatTokenV2_1_1 is FiatTokenV2_1 {
    /**
     * @notice Burn function compliant with the IL2StandardERC20 interface
     * @param _from The address to transfer tokens from to burn
     * @param _amount The amount of tokens to burn
     */
    function burn(
        address _from,
        uint256 _amount
    )
        external
        whenNotPaused
        onlyMinters
        notBlacklisted(msg.sender)
        notBlacklisted(_from)
    {
        uint256 balance = balances[_from];
        require(_amount > 0, "FiatToken: burn amount not greater than 0");
        require(balance >= _amount, "FiatToken: burn amount exceeds balance");
        require(
            _amount <= allowed[_from][msg.sender],
            "ERC20: transfer amount exceeds allowance"
        );

        totalSupply_ = totalSupply_ - _amount;
        balances[_from] = balance - _amount;
        emit Burn(_from, _amount);
        emit Transfer(_from, address(0), _amount);
    }
}
