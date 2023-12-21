// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VoltaToken is ERC20Burnable, ERC20Capped, Ownable {

    mapping(address => bool hasPermission) public isMinter;
    mapping(address => uint256 timeToSetMinter) public minterTimer;

    event SetMinter(address indexed minter, uint256 indexed timeUntilMinter);
    event RemoveMinter(address indexed minter);
    event ConfirmMinter(address indexed minter);

    constructor() ERC20("Volta Protocol Token", "VOLTA") ERC20Capped(100_000_000 * 10 ** decimals()) {
        _mint(msg.sender, 100_000_000 * 10 ** decimals());
    }

    function setMinter(address _minter, bool _isMinter) external onlyOwner {
        if (_isMinter) {
            minterTimer[_minter] = block.timestamp + 2 days;
            emit SetMinter(_minter, block.timestamp + 2 days);
        } else {
            delete minterTimer[_minter];
            delete isMinter[_minter];
            emit RemoveMinter(_minter);
        }
    }

    function confirmMinter(address _minter) external onlyOwner {
        require(minterTimer[_minter] != 0 && block.timestamp > minterTimer[_minter], "Minter not ready");
        delete minterTimer[_minter];
        isMinter[_minter] = true;
        emit ConfirmMinter(_minter);
    }

    function mint(address _account, uint256 _amount) external {
        require(isMinter[msg.sender], "!Minter");
        _mint(_account, _amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        ERC20Capped._mint(account, amount);
    }
}
