//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

import './Claimable.sol';

contract Administrable is Claimable {
    mapping(address => bool) public isAdmin;

    event AdminAppointed(address admin);
    event AdminDismissed(address admin);

    constructor() {
        isAdmin[owner] = true;

        emit AdminAppointed(owner);
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], 'NOT_AN_ADMIN');
        _;
    }

    function appointAdmin(address _newAdmin) public onlyContractOwner() returns (bool success) {
        if (isAdmin[_newAdmin] == false) {
            isAdmin[_newAdmin] = true;
        }

        emit AdminAppointed(_newAdmin);
        return true;
    }

    function dismissAdmin(address _admin) public onlyContractOwner() returns (bool success) {
        isAdmin[_admin] = false;

        emit AdminDismissed(_admin);
        return true;
    }
}
