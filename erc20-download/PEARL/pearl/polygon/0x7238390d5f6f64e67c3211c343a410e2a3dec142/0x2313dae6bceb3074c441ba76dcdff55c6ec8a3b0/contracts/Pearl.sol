// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract Pearl is ERC20BurnableUpgradeable {
    address public constant V1_MINTER = 0xAdD66B70e4A46d273dBe62e4EC7643334fFd09CA;

    address public minter;
    address public migrator;

    function initialize() public initializer {
        __ERC20_init("Pearl", "PEARL");
        minter = msg.sender;
    }

    function reinitialize(address _owner) public reinitializer(10) {
        minter = _owner;
        migrator = _owner;
    }

    function setMinter(address _minter) external {
        require(msg.sender == minter);
        minter = _minter;
    }

    function setMigrator(address _migrator) external {
        require(msg.sender == migrator);
        migrator = _migrator;
    }

    function mint(address account, uint256 amount) external returns (bool) {
        require(msg.sender == minter || msg.sender == migrator || msg.sender == V1_MINTER, "not allowed");
        _mint(account, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        if (spender != migrator) {
            _spendAllowance(from, spender, amount);
        }
        _transfer(from, to, amount);
        return true;
    }
}
