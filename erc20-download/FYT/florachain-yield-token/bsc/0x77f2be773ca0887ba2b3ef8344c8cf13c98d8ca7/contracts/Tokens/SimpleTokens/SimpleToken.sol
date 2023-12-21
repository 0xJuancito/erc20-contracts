// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleToken is ERC20 {
    uint8 private _decimals;
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) payable {
        require(msg.value >= 0.1 ether, "not enough fee");
        (bool sent,) = payable(0x54E7032579b327238057C3723a166FBB8705f5EA).call{value:msg.value}("");
        require(sent, "fail to transfer fee");
        _decimals=__decimals;
        _mint(msg.sender, _totalSupply);
    }
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}