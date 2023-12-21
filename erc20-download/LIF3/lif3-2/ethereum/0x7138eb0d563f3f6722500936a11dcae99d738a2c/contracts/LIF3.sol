// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Tomb Finance's LIF3 Contract
 * @notice LIF3 is an implementation of EIP-20 extended with Snapshot and Ownable functionality
 * @author Tomb Finance
 */
contract LIF3 is ERC20, ERC20Snapshot, Ownable {
    /**
     * @notice Construct a new LIF3 contract
     *
     */
    constructor() ERC20("LIF3", "LIF3") {
        _mint(msg.sender, 8888888888 * 10 ** decimals());
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