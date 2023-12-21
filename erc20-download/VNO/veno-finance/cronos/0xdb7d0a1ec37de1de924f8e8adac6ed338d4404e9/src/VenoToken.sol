// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VenoToken is ERC20, Ownable {
    constructor() ERC20("VenoToken", "VNO") {}

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (Storm).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
