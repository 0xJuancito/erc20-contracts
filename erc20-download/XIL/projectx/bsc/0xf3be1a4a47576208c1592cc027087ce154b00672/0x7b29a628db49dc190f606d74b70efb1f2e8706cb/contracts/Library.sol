//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";

contract token is ERC20PresetMinterPauserUpgradeable {
    struct TransferData {
        address recipient;
        uint256 amount;
    }

    function tokenInit(
        string memory _name,
        string memory _symbol,
        uint256 totalSupply
    ) public virtual initializer {
        __ERC20PresetMinterPauser_init(_name, _symbol);
        _mint(_msgSender(), totalSupply);
    }

    /**
     * @dev loops though an array "data" of TransferData
     * and makes "data.length" transactions
     */
    function batchTransfer(TransferData[] calldata data) external {
        address sender = _msgSender();
        for (uint256 i = 0; i < data.length; i++) {
            _transfer(sender, data[i].recipient, data[i].amount);
        }
    }
}

contract BEP20 is token {
    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }
}

contract ERC20 is token {}
