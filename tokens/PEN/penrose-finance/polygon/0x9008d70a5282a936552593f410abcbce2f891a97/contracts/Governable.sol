// SPDX-License-Identifier: MIT
pragma solidity 0.8.11||0.6.12;

/**
 * @title Ownable contract which allows governance to be killed
 * @author Penrose
 */
contract Governable {
    address public governanceAddress;
    bool public governanceIsKilled;

    /**
     * @notice By default governance is msg.sender
     * @dev public visibility so it compiles for 0.6.12
     */
    constructor() public {
        governanceAddress = msg.sender;
    }

    /**
     * @notice Only allow governance to perform certain actions
     */
    modifier onlyGovernance() {
        require(msg.sender == governanceAddress, "Only governance");
        _;
    }

    /**
     * @notice Set governance address
     * @param _governanceAddress The address of new governance
     */
    function setGovernanceAddress(address _governanceAddress)
        external
        onlyGovernance
    {
        governanceAddress = _governanceAddress;
    }

    /**
     * @notice Allow governance to be killed
     */
    function killGovernance() external onlyGovernance {
        governanceAddress = address(0);
        governanceIsKilled = true;
    }
}
