// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ILBPair, IERC20} from "joe-v2/interfaces/ILBPair.sol";

interface IFloorToken {
    event FloorRaised(uint256 newFloorId);

    event RoofRaised(uint256 newRoofId);

    event RebalancePaused();

    event RebalanceUnpaused();

    function MAX_NUM_BINS() external view returns (uint256);

    function pair() external view returns (ILBPair);

    function tokenY() external view returns (IERC20);

    function binStep() external view returns (uint16);

    function floorPerBin() external view returns (uint256);

    function floorPrice() external view returns (uint256);

    function range() external view returns (uint24, uint24);

    function rebalancePaused() external view returns (bool);

    function tokensInPair() external view returns (uint256, uint256);

    function calculateNewFloorId() external view returns (uint24);

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function rebalanceFloor() external;

    function raiseRoof(uint24 nbBins) external;

    function pauseRebalance() external;

    function unpauseRebalance() external;
}
