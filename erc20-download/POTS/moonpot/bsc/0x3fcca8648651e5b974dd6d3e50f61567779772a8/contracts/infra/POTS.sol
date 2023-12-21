pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract POTS is ERC20 {
    constructor() ERC20("Moonpot", "POTS") public {
        _mint(msg.sender, 10_000_000 * 1e18);
    }
}