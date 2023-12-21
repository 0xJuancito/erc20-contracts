// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "./IBEP20.sol";

interface IStakedBNBToken is IERC777, IBEP20 {
    function mint(
        address account,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) external;

    function pause() external;

    function unpause() external;

    function selfDestruct() external;
}
