// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "../utils/Context.sol";
import "./Ownable.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract AdminRole is Ownable {

    mapping(address => bool) _adminAddress;
    modifier onlyAdmin() {
        require(_adminAddress[_msgSender()] == true , "COCM: caller is not a admin");
        _;
    }
    event AdminSet(address indexed from, address indexed newAdmin, bool action);

    /**
     * @dev Initializes the contract setting the deployer as a admin.
     */
    constructor () {
        _adminAddress[_msgSender()] = true;
    }

    /**
   * @dev Add to list of admin `newAdmin_` address
   *
   * Emits an {AddedAdmin} event
   *
   * Requirements:
   * - Caller **MUST** is an admin
   * - `newAdmin_` address **MUST** is not an admin
   */
    function addAdmin(address newAdmin_) public onlyAdmin returns (bool){
        require(_adminAddress[newAdmin_] == false, "COCM: Address is already admin");
        _adminAddress[newAdmin_] = true;

        emit AdminSet(_msgSender(), newAdmin_, true);
        return true;
    }

    /**
    * @dev Remove to list of admin `newAdmin_` address
    *
    * Emits an {AddedAdmin} event
    *
    * Requirements:
    * - Caller **MUST** is an admin
    * - newAdmin_ address **MUST** is an admin
    */
    function removeAdmin(address adminToRemove_) public onlyAdmin returns (bool){
        require(_adminAddress[_msgSender()] == true, "COCM: Address is not a admin");
        _adminAddress[adminToRemove_] = false;

        emit AdminSet(_msgSender(), adminToRemove_, false);
        return true;
    }

    /**
    * @dev Return if `adminAddress_` is admin
    */
    function checkIfAdmin(address adminAddress_) public view returns(bool) {
        return _adminAddress[adminAddress_];
    }
}
