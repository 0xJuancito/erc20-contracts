// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";

// Import ERC20
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract WrappedARC is ERC20, ERC20Burnable {
    address public bridge;

    constructor(address _bridge) ERC20("WrappedARC", "WARC") {
        bridge = _bridge;
    }

    modifier onlyBridge() {
        require(
            bridge == msg.sender,
            "WARC: only the bridge can trigger this method!"
        );
        _;
    }

    function mint(address _recipient, uint256 _amount)
        public
        virtual
        onlyBridge
    {
        _mint(_recipient, _amount);
        console.log("Tokens minted for %s", _recipient);
    }

    function burnFrom(address _account, uint256 _amount)
        public
        virtual
        override(ERC20Burnable)
        onlyBridge
    {
        super.burnFrom(_account, _amount);
        console.log("Tokens burned from %s", _account);
    }

    function updateBridge(address _bridge) 
        public
        virtual
        onlyBridge
    {
        bridge = _bridge;
        console.log("Bridge wallet changed to %s", _bridge);
    }
}
