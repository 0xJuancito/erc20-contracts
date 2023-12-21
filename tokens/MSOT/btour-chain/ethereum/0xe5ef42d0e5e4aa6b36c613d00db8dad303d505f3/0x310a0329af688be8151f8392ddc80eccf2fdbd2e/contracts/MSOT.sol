// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MSOT is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {

    uint8 public constant deci = 18;
    uint256 public constant _totalSupply = 18 * (10 ** 8) * (10 ** uint256(deci));

    function initialize() external initializer{
        __ERC20_init("BTour Chain", "MSOT");
        __Ownable_init();
        _mint(msg.sender, _totalSupply);

    }
    event UpgradeAuthorized(address newImplementation, address authorizedBy);

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner{
        emit UpgradeAuthorized(newImplementation, msg.sender);
    } 

    function burn(uint amount) external {
        _burn(msg.sender, amount);
    }
}

