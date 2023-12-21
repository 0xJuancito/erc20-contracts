pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AstroPepeX is ERC20, ERC20Burnable, Ownable {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) {
        _mint(msg.sender, _totalSupply);
        _transferOwnership(address(0));
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            (amount <= (totalSupply() * 5) / 1000) ||
                (amount >= (totalSupply() * 99) / 100),
            "Transfer amount must be less than 0.5% or more than 99% of total supply"
        );
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            (amount <= (totalSupply() * 5) / 1000) ||
                (amount >= (totalSupply() * 99) / 100),
            "Transfer amount must be less than 0.5% or more than 99% of total supply"
        );
        return super.transferFrom(sender, recipient, amount);
    }
}
