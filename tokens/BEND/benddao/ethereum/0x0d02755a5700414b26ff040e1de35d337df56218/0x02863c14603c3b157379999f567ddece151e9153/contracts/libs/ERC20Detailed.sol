// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

contract ERC20Detailed is ERC20PermitUpgradeable {
    uint8 private __decimals;

    function __ERC20Detailed_init(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) internal initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __decimals = _decimals;
    }

    /**
     * @return the decimals of the token
     **/

    function decimals() public view virtual override returns (uint8) {
        return __decimals;
    }
}
