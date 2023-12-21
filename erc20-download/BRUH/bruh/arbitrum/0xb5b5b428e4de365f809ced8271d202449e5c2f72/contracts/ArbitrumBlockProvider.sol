// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ArbSys {
    function arbBlockNumber() external view returns(uint);
}

library ArbitrumBlockProvider {
    function blockNumber() internal view returns(uint) {
        return ArbSys(address(100)).arbBlockNumber();
    }
}
