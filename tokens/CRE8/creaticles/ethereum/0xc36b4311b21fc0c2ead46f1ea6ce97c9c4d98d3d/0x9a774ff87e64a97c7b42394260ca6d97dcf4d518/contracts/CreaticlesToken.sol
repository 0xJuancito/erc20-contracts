//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ERC777UpgradeableLocal.sol";

contract CreaticlesToken is ERC777Upgradeable {

    function initialize(string memory name, string memory symbol, uint256 supply, address registry_address) public initializer {
        address[] memory operators;
        ERC777Upgradeable.__ERC777_init_unchained(name, symbol, registry_address, operators);
        ERC777Upgradeable._mint(_msgSender(), supply, "0x", "0x");
    }
}
