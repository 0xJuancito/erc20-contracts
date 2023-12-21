// contracts/Token.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is Ownable, ERC20 {

    address private _owner;
    uint256 private _maxSupply;

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _owner = _msgSender();
        _maxSupply = initialSupply;
    }

    function mint(address account, uint256 amount) onlyOwner public {
        require(totalSupply() + amount < _maxSupply, "Token: mint amount exceeds maxSupply");
        _mint(account, amount);
    }

    function changeOwner(address address_) onlyOwner public {
        require(_msgSender() == _owner, "only owner address can change");
        _owner = address_;
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

}
