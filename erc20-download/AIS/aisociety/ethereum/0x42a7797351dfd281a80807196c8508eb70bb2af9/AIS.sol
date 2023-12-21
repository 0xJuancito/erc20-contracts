// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IAISocietyToken.sol";

contract AIS is IAISocietyToken {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _amount
    ) ERC20(_name, _symbol) {
        setMaxSupply(_amount * 10**decimals());
        _mint(_msgSender(), maxSupply());
    }

    //Don't accept ETH or BNB
    receive() external payable {
        revert("Don't accept ETH or BNB");
    }
}
