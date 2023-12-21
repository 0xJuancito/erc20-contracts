// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "ERC20PresetMinterPauserUpgradeable.sol";

contract A4Token is ERC20PresetMinterPauserUpgradeable {

    mapping(address => bool) public isTrustedForwarder;

    function init(string calldata symbol, string calldata name) external initializer {
        __ERC20PresetMinterPauser_init(symbol, name);
    }

    function burn(address to, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have minter role to burn");
        _burn(to, amount);
    }

    function adminSetForwarder(address forwarder, bool valid) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have admin role to set");
        isTrustedForwarder[forwarder] = valid;
    }

    function _msgSender() internal override view returns (address) {
        address signer = msg.sender;
        if (msg.data.length >= 20 && isTrustedForwarder[signer]) {
            assembly {
                signer := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        }
        return signer;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}