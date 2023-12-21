// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;


interface ILiquidityRestrictor {

    function assureByAgent(address token, address from, address to) external returns (bool allow, string memory message);
    function assureLiquidityRestrictions(address from, address to) external returns (bool allow, string memory message);

}
