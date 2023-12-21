pragma solidity 0.5.8;

import "./Admin.sol";
import "./MinterAdmin.sol";

contract Owner is Admin, MinterAdmin {
    address public owner = address(0);

    event OwnerChanged(address indexed oldOwner, address indexed newOwner, address indexed sender);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin, address indexed sender);
    event MinterAdminChanged(address indexed oldMinterAdmin, address indexed newMinterAdmin, address indexed sender);

    modifier onlyOwner() {
        require(msg.sender == owner, "the sender is not the owner");
        _;
    }

    function changeOwner(address _account) public onlyOwner whenNotPaused isNotZeroAddress(_account) {
        address old = owner;
        owner = _account;
        emit OwnerChanged(old, owner, msg.sender);
    }

    /**
     * Change Admin
     * @dev "whenNotPaused" modifier should not be used here
     */
    function changeAdmin(address _account) public onlyOwner isNotZeroAddress(_account) {
        address old = admin;
        admin = _account;
        emit AdminChanged(old, admin, msg.sender);
    }

    function changeMinterAdmin(address _account) public onlyOwner whenNotPaused isNotZeroAddress(_account) {
        address old = minterAdmin;
        minterAdmin = _account;
        emit MinterAdminChanged(old, minterAdmin, msg.sender);
    }
}