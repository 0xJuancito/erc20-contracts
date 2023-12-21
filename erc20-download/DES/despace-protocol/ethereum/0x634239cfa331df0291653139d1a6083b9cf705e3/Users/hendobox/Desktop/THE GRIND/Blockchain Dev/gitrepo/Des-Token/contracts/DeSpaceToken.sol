//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract DeSpaceToken is ERC20Burnable, Ownable {

    event ReturnedERC20(address indexed token, address indexed receiver, uint amount);

    constructor(uint256 initialSupply) ERC20("DeSpace Protocol", "DES") {
        _mint(msg.sender, initialSupply);
    }

    function returnERC20(address _token, address _to, uint _amount) external onlyOwner() {
        
        require(_token != address(0), "invalid _token address");
        require(_to != address(0), "invalid _to address");
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "insufficient token balance");

        IERC20(_token).transfer(_to, _amount);  
        emit ReturnedERC20(_token, _to, _amount);
    }
}