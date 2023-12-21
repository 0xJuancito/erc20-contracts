// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

import "./AdminRole.sol";/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is AdminRole {
    event Pause();
    event Unpause();
    event NotPausable();

    bool public paused = false;
    bool public canPause = true;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused || checkIfAdmin(_msgSender()));
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     **/
    function pause() onlyAdmin whenNotPaused public {
        require(paused == false);
        require(canPause == true);
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() onlyAdmin whenPaused public {
        require(paused == true);
        paused = false;
        emit Unpause();
    }

    /**
     * @dev Prevent the token from ever being paused again
     **/
    function notPausable() onlyAdmin public{
        paused = false;
        canPause = false;
        emit NotPausable();
    }
}