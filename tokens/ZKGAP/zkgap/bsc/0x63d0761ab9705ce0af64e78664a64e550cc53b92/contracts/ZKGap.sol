// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ZKGap is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 100000000 * 10 ** 18; 

    mapping(address => bool) public minters;
    mapping(address => uint256) public mintMaxTx;
    mapping(address => uint256) public mintMaxAmount;
    mapping(address => uint256) public mintAccountAmount;

    constructor() ERC20("ZK", "ZKGAP") {
        minters[msg.sender] = true;
        mintMaxTx[msg.sender] = MAX_SUPPLY;
        mintMaxAmount[msg.sender] = MAX_SUPPLY;
    }

    modifier onlyMinter() {
        require(minters[msg.sender], "Not a minting role");
        _;
    }

    function setMinter(address _admin, uint256 _mintMaxTx, uint256 _mintMaxAmount, bool _status) public onlyOwner {
        minters[_admin] = _status;
        mintMaxTx[_admin] = _mintMaxTx;
        mintMaxAmount[_admin] = _mintMaxAmount;
    }

    function mint(address to, uint256 amount) public onlyMinter {
        uint256 currentSupply = totalSupply();
        require(currentSupply + amount <= MAX_SUPPLY, "Exceeds maximum total supply");
        require(amount <= mintMaxTx[msg.sender], "Exceeds tx mint");
        require(amount + mintAccountAmount[msg.sender] <= mintMaxAmount[msg.sender], "Exceeds maximum tx mint");

        mintAccountAmount[msg.sender] += amount;
        _mint(to, amount);
    }
}
