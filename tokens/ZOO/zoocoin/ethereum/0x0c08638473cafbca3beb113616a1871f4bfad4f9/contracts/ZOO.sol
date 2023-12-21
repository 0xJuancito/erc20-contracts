// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ZOO is ERC20, ERC20Snapshot, Ownable {
    /**
     * @notice Construct a new LIF3 contract
     *
     */
    constructor() ERC20("ZOO", "ZOO") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }

    /**
     * @notice Make a snapshot
     */
    function snapshot() public onlyOwner {
        _snapshot();
    }
    
    /**
     * @notice Recover tokens
     * @param token The address of the recovery subject
     */
    function recover(address token) public {
       IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}