pragma solidity ^0.5.0;

import "./Roles.sol";
import "./Ownable.sol";

contract PauserRole is Ownable {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(0xC4F551FcCf5B7E5d7ECd31BBa135B989369d5fE3);
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender));
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyOwner {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function removePauser(address account) public onlyOwner {
        _removePauser(account);
    }

    function _removePauser(address account) internal  {
        _pausers.remove(account);
        emit PauserRemoved(account);
    }
}
