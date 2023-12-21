//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OpenX is ERC20 {
    constructor() public ERC20("OpenX Optimism", "OpenX") {
        _setupDecimals(18);
        _mint(msg.sender, 16624999990000000000000000);
    }


    function burn(uint256 _amount) public {
    	_burn(msg.sender, _amount);
    }
}