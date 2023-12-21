// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/DelegateERC20.sol";

contract Metagame is DelegateERC20, Ownable {
    uint256 private constant maxSupply =  3 * 10**7  * 1e18;     // the total supply

    constructor(address _owner)  ERC20("Metagame Arena", "MGA"){
        _mint(_owner, maxSupply);
    }

}