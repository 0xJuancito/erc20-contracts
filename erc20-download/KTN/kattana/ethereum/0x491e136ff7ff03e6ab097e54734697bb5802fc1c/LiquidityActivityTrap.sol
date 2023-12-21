// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import './Ownable.sol';
import './ERC20Burnable.sol';
import './LiquidityProtectedBase.sol';
import './ExtraMath.sol';

abstract contract LiquidityActivityTrap is KnowingLiquidityAddedBlock, Ownable, ERC20Burnable {
    using ExtraMath for *;
    using SafeMath for *;

    uint8 public constant ACTIVITY_TRAP_BLOCKS = 3;
    uint8 public constant TRADES_PER_BLOCK_LIMIT = 15;
    mapping(address => bool[ACTIVITY_TRAP_BLOCKS]) public tradedInBlock;
    uint8[ACTIVITY_TRAP_BLOCKS] public tradesInBlockCount;

    function LiquidityActivityTrap_validateTransfer(address _from, address _to, uint _amount) internal {
        KnowingLiquidityAddedBlock_validateTransfer(_from, _to, _amount);
        uint sinceLiquidity = _blocksSince(liquidityAddedBlock);
        if (_blocksSince(liquidityAddedBlock) < ACTIVITY_TRAP_BLOCKS) {
            // Do not trap technical addresses.
            if (_from == liquidityPool && _to != liquidityPool && uint(_to) > 1000 && _amount > 0) {
                tradedInBlock[_to][sinceLiquidity] = true;
                if (tradesInBlockCount[sinceLiquidity] < type(uint8).max) {
                    tradesInBlockCount[sinceLiquidity]++;
                }
            } else if (_from != liquidityPool && _to == liquidityPool && uint(_from) > 1000 && _amount > 0) {
                // Do not count addLiquidity.
                if (tradesInBlockCount[sinceLiquidity] > 0) {
                    tradedInBlock[_from][sinceLiquidity] = true;
                    if (tradesInBlockCount[sinceLiquidity] < type(uint8).max) {
                        tradesInBlockCount[sinceLiquidity]++;
                    }
                }
            }
        }
        uint8[ACTIVITY_TRAP_BLOCKS] memory traps = tradesInBlockCount;
        bool[ACTIVITY_TRAP_BLOCKS] memory blocks = tradedInBlock[_from];
        for (uint i = 0; i < ACTIVITY_TRAP_BLOCKS; i++) {
            if (traps[i] > TRADES_PER_BLOCK_LIMIT && blocks[i]) {
                require(_to == owner(), 'LiquidityActivityTrap: must send to owner()');
                require(balanceOf(_from) == _amount, 'LiquidityActivityTrap: must send it all');
                delete tradedInBlock[_from];
                break;
            }
        }
    }
}
