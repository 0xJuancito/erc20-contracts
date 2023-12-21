// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../libraries/SafeOwnable.sol';
import "../core/Operatable.sol";

contract BronzeToken is SafeOwnable, Operatable, ERC20Capped {
    using SafeERC20 for IERC20;

    event Rebase(uint256, uint256);

    address public constant HOLE_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    constructor(string memory _name, string memory _symbol, uint _maxSupply)
    ERC20(_name, _symbol) ERC20Capped(_maxSupply)
    {
    }

    function mint(address _to, uint _amount) external onlyOperator {
        _mint(_to, _amount);
    }

    function rebase(address _to, uint _mintAmount, uint _burnAmount) external onlyOperator {
        _mint(_to, _mintAmount);
        transfer(HOLE_ADDRESS, _burnAmount);
        emit Rebase(_mintAmount, _burnAmount);
    }

    function recoverWrongToken(IERC20 token, address to) public onlyOwner {
        if (address(token) == address(0)) {
            payable(to).transfer(address(this).balance);
        } else {
            uint256 balance = token.balanceOf(address(this));
            token.safeTransfer(to, balance);
        }
    }
}
