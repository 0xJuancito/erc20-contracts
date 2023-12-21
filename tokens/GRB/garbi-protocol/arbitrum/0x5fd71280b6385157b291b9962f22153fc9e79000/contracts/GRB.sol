// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GRB is ERC20Burnable, Ownable {
    using SafeMath for uint256;

    uint256 public immutable MAX_SUPPLY;

    uint256 public totalBurned = 0;

    constructor(
        uint256 _maxSupply,
        uint256 _initialSupply
    ) ERC20("GarbiProtocol", "GRB"){
        require(_initialSupply <= _maxSupply, "GRB: The _initialSupply should not exceed the _maxSupply");
        MAX_SUPPLY = _maxSupply;

        if (_initialSupply > 0) {
           _mint(_msgSender(), _initialSupply);
        }
    }
    /************************************************************************/

    function _burn(address account, uint256 amount) internal override {
        super._burn(account, amount);
        totalBurned = totalBurned.add(amount);
    }
    /************************************************************************/

    function mint(address _user, uint256 _amount) external onlyOwner {
        uint256 _totalSupply = totalSupply();
        require(_totalSupply.add(_amount) <= MAX_SUPPLY, "GRB: No more minting allowed!");

        _mint(_user, _amount);
    }

}