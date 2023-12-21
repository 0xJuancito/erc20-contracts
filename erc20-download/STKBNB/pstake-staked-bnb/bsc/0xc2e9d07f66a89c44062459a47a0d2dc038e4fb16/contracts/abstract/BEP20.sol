//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "../interfaces/IBEP20.sol";

abstract contract BEP20 is IBEP20 {
    /*********************
     * STATE VARIABLES
     ********************/

    // Owner for the BEP20 token
    address internal _owner;

    /*********************
     * ERRORS
     ********************/
    error CallerIsNotTheOwner();
    error NewOwnerIsTheZeroAddress();

    /*********************
     * MODIFIERS
     ********************/

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        if (msg.sender != _owner) {
            revert CallerIsNotTheOwner();
        }
    }

    /*********************
     * CONTRACT LOGIC
     ********************/

    constructor(address owner) {
        _owner = owner;
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view override returns (address) {
        return _owner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     * Emits the `OwnershipTransferred` event.
     *
     * Note that this is copied form the Ownable contract in Openzeppelin contracts.
     * We don't need rest of the functionalities from Ownable, including `renounceOwnership`
     * as we always want to have an owner for this contract.
     */
    function transferOwnership(address newOwner) external override onlyOwner {
        if (newOwner == address(0)) {
            revert NewOwnerIsTheZeroAddress();
        }

        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
