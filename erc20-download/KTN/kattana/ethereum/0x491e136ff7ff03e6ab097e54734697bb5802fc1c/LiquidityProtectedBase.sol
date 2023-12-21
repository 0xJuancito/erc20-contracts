// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import './UniswapV2Library.sol';
import './ExtraMath.sol';

abstract contract LiquidityProtectedBase {
    address public liquidityPool;

    constructor(address _uniswapV2Factory, address _pairToken) {
        liquidityPool = UniswapV2Library.pairFor(_uniswapV2Factory, _pairToken, address(this));
    }

    function _blocksSince(uint _blockNumber) internal view returns(uint) {
        if (_blockNumber > block.number) {
            return 0;
        }
        return block.number - _blockNumber;
    }
}

abstract contract KnowingLiquidityAddedBlock is LiquidityProtectedBase {
    using ExtraMath for *;
    uint96 public liquidityAddedBlock;

    function KnowingLiquidityAddedBlock_validateTransfer(address, address _to, uint _amount) internal {
        if (liquidityAddedBlock == 0 && _to == liquidityPool && _amount > 0) {
            liquidityAddedBlock = block.number.toUInt96();
        }
    }
}
