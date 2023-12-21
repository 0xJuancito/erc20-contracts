// SPDX-License-Identifier: agpl-3.0

pragma solidity 0.8.9;

import "../../interfaces/ISystemPause.sol";

abstract contract AbstractSystemPause {
    /// bool to store system status
    bool public systemPaused;
    /// System pause interface
    ISystemPause system;

    /* ========== ERROR STATEMENTS ========== */

    error UnauthorisedAccess();
    error SystemPaused();

    /**
     @dev this modifier calls the SystemPause contract. SystemPause will revert
     the transaction if it returns true.
     */
    modifier onlySystemPauseContract() {
        if (address(system) != msg.sender) revert UnauthorisedAccess();
        _;
    }

    /**
     @dev this modifier calls the SystemPause contract. SystemPause will revert
     the transaction if it returns true.
     */

    modifier whenSystemNotPaused() {
        if (systemPaused) revert SystemPaused();
        _;
    }

    function pauseSystem() public virtual onlySystemPauseContract {
        systemPaused = true;
    }

    function unpauseSystem() public virtual onlySystemPauseContract {
        systemPaused = false;
    }

    function pauseStatus() public virtual view returns(bool) {
        return systemPaused;
    }
}
