// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../governance/Governable.sol";

abstract contract MultiMinter is Governable {
    error NotMinter();

    mapping(address => bool) public minters;

    modifier onlyMinter() {
        if (!minters[msg.sender]) revert NotMinter();
        _;
    }

    function setMinter(address _minter, bool _enabled) external onlyGov {
        minters[_minter] = _enabled;
    }
}
