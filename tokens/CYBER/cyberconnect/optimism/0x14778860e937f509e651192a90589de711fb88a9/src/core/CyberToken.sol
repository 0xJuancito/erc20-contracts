// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { ERC20Burnable } from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Votes } from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
 * @dev The CyberConnect ERC20 token.
 * Implements governance functionality with voting and delegation.
 * Implements EIP 2612 allowing signed approvals.
 * Support token holder to burn token or burnFrom others by allowance.
 * Only the owner address has permission to mint.
*/

contract CyberToken is ERC20Burnable, ERC20Votes, Ownable {

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("CyberConnect", "CYBER") ERC20Permit("CyberConnect") {}

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC
    //////////////////////////////////////////////////////////////*/

    function mint(address _account, uint256 _amount) public onlyOwner {
        _mint(_account, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }
}
