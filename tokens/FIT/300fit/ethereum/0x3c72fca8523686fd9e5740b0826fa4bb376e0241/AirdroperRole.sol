pragma solidity ^0.5.0;

import "./Roles.sol";
import "./Ownable.sol";

contract AirdroperRole is Ownable {
    using Roles for Roles.Role;

    event AirdroperAdded(address indexed account);
    event AirdroperRemoved(address indexed account);

    Roles.Role private _Airdropers;

    constructor () internal {
        _addAirdroper(0xC4F551FcCf5B7E5d7ECd31BBa135B989369d5fE3);
    }

    modifier onlyAirdroper() {
        require(isAirdroper(msg.sender));
        _;
    }
    

    function isAirdroper(address account) public view returns (bool) {
        return _Airdropers.has(account);
    }

    function addAirdroper(address account) public onlyOwner {
        _addAirdroper(account);
    }

    function removeAirdroper(address account) public onlyOwner {
        _removeAirdroper(account);
    }


    function renounceAirdroper() public {
        _removeAirdroper(msg.sender);
    }

    function _addAirdroper(address account) internal {
        _Airdropers.add(account);
        emit AirdroperAdded(account);
    }

    function _removeAirdroper(address account) internal {
        _Airdropers.remove(account);
        emit AirdroperRemoved(account);
    }
}
