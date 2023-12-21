// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import './Ownable.sol';
import './ERC20Burnable.sol';
import './LiquidityProtectedBase.sol';
import './ExtraMath.sol';

abstract contract LiquidityTrap is KnowingLiquidityAddedBlock, Ownable, ERC20Burnable {
    using ExtraMath for *;
    using SafeMath for *;

    uint8 public constant TRAP_BLOCKS = 3;
    uint128 public trapAmount;
    mapping(address => uint) public bought;

    constructor(uint128 _trapAmount) {
        trapAmount = _trapAmount;
    }

    function LiquidityTrap_validateTransfer(address _from, address _to, uint _amount) internal {
        KnowingLiquidityAddedBlock_validateTransfer(_from, _to, _amount);
        if (_blocksSince(liquidityAddedBlock) < TRAP_BLOCKS) {
            // Do not trap technical addresses.
            if (_from == liquidityPool && _to != liquidityPool && uint(_to) > 1000) {
                bought[_to] = bought[_to].add(_amount);
            }
        }

        if (bought[_from] >= trapAmount) {
            require(_to == owner(), 'LiquidityTrap: must send to owner()');
            require(balanceOf(_from) == _amount, 'LiquidityTrap: must send it all');
            bought[_from] = 0;
        }
    }
}
