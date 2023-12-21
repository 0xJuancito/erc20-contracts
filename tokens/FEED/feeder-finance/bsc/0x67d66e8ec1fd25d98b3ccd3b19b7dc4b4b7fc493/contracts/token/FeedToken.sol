// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";

contract FeedToken is ERC20Capped, Ownable {
    address public treasuryAddress;

    constructor(address _treasury, uint256 _cap) ERC20("Feeder.finance", "FEED") ERC20Capped(_cap) {
        treasuryAddress = _treasury;

        mintTo(treasuryAddress, 31750000 ether);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner.
    function mintTo(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
