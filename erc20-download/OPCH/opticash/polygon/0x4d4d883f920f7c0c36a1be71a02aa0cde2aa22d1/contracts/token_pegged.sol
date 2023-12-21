// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

interface ArbitraryTokenStorage {
    function unlockERC(IERC20 token,address to) external;
}

contract ERC20Storage is AccessControlEnumerable, ArbitraryTokenStorage {
    function unlockERC(IERC20 token,address to) external virtual override {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have Admin role");
        require(address(token) != address(0),"Token Address cannot be address 0");
        require(address(to) != address(0),"Reciever Address cannot be address 0");
        
        uint256 balance = token.balanceOf(address(this));

        require(balance > 0, "Contract has no balance");
        require(token.transfer(to, balance), "Transfer failed");
    }
}

contract OPCH is ERC20Burnable, AccessControlEnumerable {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant maxSupply = 1000 * (10**6) * 10**18;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function mint(address to, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "Must have minter role to mint");
        require(totalSupply()+amount <=maxSupply, "Cannot mint more than maxsupply");
        
        _mint(to, amount);
    }
}
