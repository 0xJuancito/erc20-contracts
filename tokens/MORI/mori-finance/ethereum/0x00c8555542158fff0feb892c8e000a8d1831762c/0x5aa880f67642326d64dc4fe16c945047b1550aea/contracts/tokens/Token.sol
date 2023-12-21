// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title Token is an ERC20-compliant token.
 * - Token can only be exchanged to EsToken in the vester contract.
 * - Apart from the initial production, Token can only be produced by destroying EsToken in the Vester contract.
 */
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract Token is OwnableUpgradeable, ERC20Upgradeable {
    uint256 public constant MAX_SUPPLY = 1_000_000 * 1e18;
    mapping(address => bool) public tokenMinter;

    function initialize() public initializer {
        __Ownable_init();
        __ERC20_init("MORI", "MORI");
    }

    function setMinter(address[] calldata _contracts, bool[] calldata _bools) external onlyOwner {
        require(_contracts.length == _bools.length, "invalid length");

        for (uint256 i = 0; i < _contracts.length; i++) {
            tokenMinter[_contracts[i]] = _bools[i];
        }
    }

    function mint(address user, uint256 amount) external returns (bool) {
        require(tokenMinter[msg.sender] == true, "not authorized");
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeding the maximum supply quantity.");
        _mint(user, amount);
        return true;
    }

    function burn(address user, uint256 amount) external returns (bool) {
        require(tokenMinter[msg.sender] == true, "not authorized");
        _burn(user, amount);
        return true;
    }
}
