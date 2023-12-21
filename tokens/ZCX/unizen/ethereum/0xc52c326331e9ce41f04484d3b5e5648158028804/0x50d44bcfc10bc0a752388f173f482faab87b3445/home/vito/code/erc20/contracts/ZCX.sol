// contracts/ZCX.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20BurnableUpgradeable.sol";

contract ZCX is Initializable, ERC20BurnableUpgradeable {

    function initialize(string memory name, string memory symbol) public virtual initializer {
        __ERC20_init(name, symbol);
        _mint(address(0xB406dAaD0B8c447E4566666F3C3986A399f75eae), 1000000000 * (10 ** uint256(decimals())));
    }

}
