// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "hardhat/console.sol";

contract Governable {
    address public gov;

    event GovernanceAuthorityTransfer(address newGov);

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
        emit GovernanceAuthorityTransfer(_gov);
    }
}