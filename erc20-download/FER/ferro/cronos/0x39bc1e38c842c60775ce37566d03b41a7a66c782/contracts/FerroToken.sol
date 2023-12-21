// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FerroToken is ERC20, Ownable {
    constructor() ERC20("FerroToken", "FER") {}

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (FerroFarm).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
