// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract PmonTokenPolygon is ERC20Burnable, AccessControlEnumerable {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private _customName;
    string private _customSymbol;

    constructor(
        string memory initName,
        string memory initSymbol
    ) ERC20(initName, initSymbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _customName = initName;
        _customSymbol = initSymbol;
    }

    function mint(address to, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "Must have minter role to mint");
        _mint(to, amount);
    }

    function setName(string memory newName) public  {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have Admin role");
        _customName = newName;
    }

    function setSymbol(string memory newSymbol) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have Admin role");
        _customSymbol = newSymbol;
    }

    function name() public view override returns (string memory) {
        return _customName;
    }

    function symbol() public view override returns (string memory) {
        return _customSymbol;
    }
}
