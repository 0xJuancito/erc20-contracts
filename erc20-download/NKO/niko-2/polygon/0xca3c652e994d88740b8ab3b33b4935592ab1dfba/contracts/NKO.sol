// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NikoToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(address receiver) ERC20("Niko Token", "NKO") {
        _mint(receiver, 3000000000 * 10**decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, receiver);
        _grantRole(MINTER_ROLE, receiver);
        _grantRole(BURNER_ROLE, receiver);
    }

    function mint(address to, uint256 amount) public {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "Caller does not have a MINTER_ROLE"
        );
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        require(
            hasRole(BURNER_ROLE, msg.sender),
            "Caller does not have a BURNER_ROLE"
        );
        _burn(from, amount);
    }
}
