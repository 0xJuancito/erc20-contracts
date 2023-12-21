// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract brDFI5 is ERC20Upgradeable {
    address private _minter;

    modifier onlyMinter() {
        require(_minter == msg.sender, "Ownable: caller is not the minter");
        _;
    }

    function initialize_coin(address minter_gateway) public initializer {
        __ERC20_init("DFI (DefiChain)", "DFI");
        _minter = minter_gateway;
        _mint(msg.sender, 300 ether); // old coins liquidity for redistribution
    }

    function change_minter(address minter_gateway) public onlyMinter {
        require(_minter == msg.sender, "DOES_NOT_HAVE_MINTER_ROLE");
        _minter = minter_gateway;
    }

    function mint(address to, uint256 amount) public onlyMinter{
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyMinter{
       _burn(from, amount);
    }
}