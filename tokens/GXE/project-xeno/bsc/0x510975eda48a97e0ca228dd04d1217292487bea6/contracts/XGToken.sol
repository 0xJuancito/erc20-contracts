// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XGToken is ERC20, ERC20Burnable, Ownable {
    event MinterTransferred(address indexed previousMinter, address indexed newMinter);

    address private _minter;
    constructor(uint256 initialSupply, address owner, address minter_) ERC20("XENO Governance Token", "GXE") {
        _minter = minter_;
        _mint(owner, initialSupply * (10 ** decimals()));
        _transferOwnership(owner);
    }

    modifier onlyMinter() {
        require(_msgSender() == getMinter(), "caller is not minter.");
        _;
    }

    function mint(uint256 amount) public onlyMinter {
        _mint(owner(), amount);
    }

    function changeMinter(address newMinter) external onlyOwner {
        address oldMinter = _minter;
        _minter = newMinter;
        emit MinterTransferred(oldMinter, newMinter);
    }

    function getMinter() public view returns(address) {
        return _minter;
    }

    function getOwner() external view returns (address){
        return owner();
    }
}