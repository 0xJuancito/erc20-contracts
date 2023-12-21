// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract Caviar is ERC20Upgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    address public operator;

    function initialize() external initializer {
        __ERC20_init("CAVIAR", "CVR");
        __Ownable_init();
    }

    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "zero");
        operator = _operator;

    }

    function mint(address _to, uint256 _amount) external {
        require(msg.sender == operator, "!authorized");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        if (msg.sender != _from) {
            _spendAllowance(_from, msg.sender, _amount);
        }
        _burn(_from, _amount);
    }
}