// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "./Context.sol";


contract TokenLock is Context {

    uint8 isLocked = 0;
    event Freezed();
    event UnFreezed();

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */

    function validLock() internal view returns (bool) {
        return isLocked == 0;
    }

    /**
     * @dev Triggers stopped state.
     */
    
    function _freeze() internal {
        isLocked = 1;
        
        emit Freezed();
    }

    /**
     * @dev Returns to normal state.
     */

    function _unfreeze() internal {
        isLocked = 0;
        
        emit UnFreezed();
    }


}