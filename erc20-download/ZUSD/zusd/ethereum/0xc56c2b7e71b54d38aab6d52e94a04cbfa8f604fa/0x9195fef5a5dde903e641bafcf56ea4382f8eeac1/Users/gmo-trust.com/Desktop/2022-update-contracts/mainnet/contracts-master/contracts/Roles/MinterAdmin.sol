pragma solidity 0.5.8;

import "./Minter.sol";

contract MinterAdmin is Minter {
    address public minterAdmin = address(0);

    event MinterChanged(address indexed oldMinter, address indexed newMinter, address indexed sender);

    modifier onlyMinterAdmin() {
        require(msg.sender == minterAdmin, "the sender is not the minterAdmin");
        _;
    }

    function changeMinter(address _account) public onlyMinterAdmin whenNotPaused isNotZeroAddress(_account) {
        address old = minter;
        minter = _account;
        emit MinterChanged(old, minter, msg.sender);
    }
}