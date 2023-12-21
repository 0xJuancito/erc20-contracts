// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../contracts/utils/Owned.sol";

contract $Owned is Owned {
    constructor(address _owner) Owned(_owner) {}
}
