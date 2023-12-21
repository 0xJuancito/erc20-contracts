// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@layerzerolabs/solidity-examples/contracts-upgradable/token/oft/OFTUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Abra is Initializable, OFTUpgradeable, UUPSUpgradeable {

    function initialize(uint _initialSupply, address _lzEndpoint) public initializer {
        __OFTUpgradeable_init("ABRA", "ABRA", _lzEndpoint, msg.sender);
        __UUPSUpgradeable_init();
        _mint(_msgSender(), _initialSupply);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}