// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract MintableERC20 is ERC20 {
    bool public inPrivateTransferMode;
    address public gov;
    address public pendingGov;

    mapping (address => bool) public isMinter;
    mapping (address => bool) public isHandler;

    event NewPendingGov(address pendingGov);
    event UpdateGov(address gov);
    event SetMinter(address minter, bool isActive);

    modifier onlyGov() {
        require(gov == _msgSender(), "MintableERC20: forbidden");
        _;
    }
    
    modifier onlyMinter() {
        require(isMinter[msg.sender], "MintalbeERC20: forbidden");
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        gov = _msgSender();
    }

    function setGov(address _gov) external onlyGov {
        pendingGov = _gov;
        emit NewPendingGov(_gov);
    }

    function acceptGov() external {
        require(_msgSender() == pendingGov);
        gov = _msgSender();
        emit UpdateGov(_msgSender());
    }

    function setMinter(address _minter, bool _isActive) external onlyGov {
        isMinter[_minter] = _isActive;
        emit SetMinter(_minter, _isActive);
    }

    function mint(address _account, uint256 _amount) external onlyMinter {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyMinter {
        _burn(_account, _amount);
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyGov {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    function setHandlers(address[] calldata _handler, bool[] calldata _isActive) external onlyGov {
        for (uint256 i = 0; i < _handler.length; i++) {
            isHandler[_handler[i]] = _isActive[i];
        }
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        if (isHandler[spender]) {
            _transfer(from, to, amount);
            return true;
        }
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _beforeTokenTransfer(address /*from*/, address /*to*/, uint256 /*amount*/) internal view override {
        if (inPrivateTransferMode) {
            require(isHandler[msg.sender], "not whitelisted");
        }
    }

}