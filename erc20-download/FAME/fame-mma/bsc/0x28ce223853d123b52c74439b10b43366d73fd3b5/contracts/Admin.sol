// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "./Ownable.sol";

// Extension for Ownable contract. Contract handle multiple admins
abstract contract Admin is Ownable {
    mapping(address => bool) public isAdmin;

    constructor() {
        isAdmin[_msgSender()] = true;
    }

    modifier onlyAdmin() {
        require(isAdmin[_msgSender()], "only-admin");
        _;
    }

    function setAdmin(address anotherAdmin) public onlyAdmin {
        isAdmin[anotherAdmin] = true;
    }

    function removeAdmin(address anotherAdmin) public onlyAdmin {
        require(isAdmin[anotherAdmin], "not-admin");
        isAdmin[anotherAdmin] = false;
    }
}
