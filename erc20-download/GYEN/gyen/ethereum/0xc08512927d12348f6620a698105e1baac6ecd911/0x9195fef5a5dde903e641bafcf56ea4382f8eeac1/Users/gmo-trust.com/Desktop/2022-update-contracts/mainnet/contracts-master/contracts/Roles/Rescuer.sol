pragma solidity 0.5.8;

import "./Common.sol";

contract Rescuer is Common  {
    address public rescuer = address(0);
    modifier onlyRescuer() {
        require(msg.sender == rescuer, "the sender is not the rescuer");
        _;
    }

    function initializeRescuer(address _account) internal {
        require(rescuer == address(0), "the rescuer can only be initiated once");
        rescuer = _account;
    }
}