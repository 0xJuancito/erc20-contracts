// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/oft/OFTUpgradeable.sol";
import "hardhat-deploy/solc_0.8/proxy/Proxied.sol";

contract ChildVext is
    Initializable,
    OFTUpgradeable,
    Proxied,
    ERC20VotesUpgradeable,
    ERC165
{
    function initialize(address _lzEndpoint) public initializer {
        __OFTUpgradeable_init("Veloce", "VEXT", _lzEndpoint);
        __ERC20Permit_init("Veloce");
        __ERC20Votes_init();
    }

    /**
    @dev internal function afterTokenTransfer
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._afterTokenTransfer(from, to, amount);
    }

    /**
    @dev internal function burn
     */
    function _burn(
        address from,
        uint256 amount
    ) internal virtual override(ERC20VotesUpgradeable, ERC20Upgradeable) {
        super._burn(from, amount);
    }

    /**
    @dev internal function mint
     */

    function _mint(
        address account,
        uint256 amount
    ) internal virtual override(ERC20VotesUpgradeable, ERC20Upgradeable) {
        super._mint(account, amount);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC165, OFTUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
