// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "./Ownable.sol";


abstract contract Pauseable is Ownable {

    event Stopped(address _owner);

    event Started(address _owner);

    bool private stopped;
    
    constructor()  {
        stopped = false;
    }

    modifier stoppable {
        require(!stopped);
        _;
    }

    function paused() public view returns (bool) {
        return stopped;
    }

    function halt() public onlyOwner {
        stopped = true;
        emit Stopped(msg.sender);
    }

    function start() public onlyOwner {
        stopped = false;
        emit Started(msg.sender);
    }
}