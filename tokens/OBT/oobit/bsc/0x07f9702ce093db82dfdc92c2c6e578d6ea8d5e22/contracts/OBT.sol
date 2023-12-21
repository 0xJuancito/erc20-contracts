// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./libs/ERC20/ERC20.sol";
import "./libs/ERC20/extensions/ERC20Burnable.sol";
import "./libs/access/Ownable.sol";

contract OBT is ERC20, ERC20Burnable, Ownable {
    string private constant _name = "Oobit";
    string private constant _symbol = "OBT";

    uint256 private immutable _cap = 10 ** 27;

    constructor () ERC20(_name, _symbol) {}

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    function mint(uint256 amount) public onlyOwner {
      _mint(msg.sender, amount);
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        require(ERC20.totalSupply() + amount <= cap(), "OBT: cap exceeded");
        super._mint(account, amount);
    }

}

