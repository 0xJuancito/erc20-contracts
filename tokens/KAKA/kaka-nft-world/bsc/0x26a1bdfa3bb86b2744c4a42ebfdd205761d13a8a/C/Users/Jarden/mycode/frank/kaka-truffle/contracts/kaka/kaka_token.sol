// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract KAKAToken is ERC20, Ownable {
    using Address for address;
    mapping(address => bool) public whiteList;
    bool public whiteListStatus;

    constructor () ERC20("KAKA Metaverse Token", "KAKA") {
        _mint(_msgSender(), 100000000 ether);
        require(totalSupply() == 100000000 ether);
    }

    function setWhiteList(address permit, bool b) public onlyOwner returns (bool) {
        whiteList[permit] = b;
        return true;
    }

    function setWhiteListStatus(bool b) public onlyOwner returns (bool) {
        whiteListStatus = b;
        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if (whiteListStatus) {
            require(!_msgSender().isContract() || whiteList[_msgSender()]);
            require(!recipient.isContract() || whiteList[recipient]);
        }

        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        if (whiteListStatus) {
            require(!_msgSender().isContract() || whiteList[_msgSender()]);
            require(!sender.isContract() || whiteList[sender]);
            require(!recipient.isContract() || whiteList[recipient]);
        }

        _transfer(sender, recipient, amount);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function burn(uint256 amount) public returns (bool) {
        _burn(_msgSender(), amount);
        require(totalSupply() >= 21000000 ether, "Burn exceeds limit");
        return true;
    }

    function burnFrom(address account, uint256 amount) public returns (bool) {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
        require(totalSupply() >= 21000000 ether, "Burn exceeds limit");
        return true;
    }
}
