// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "./interfaces/IBEP20Ownable.sol";
import "./interfaces/IDDOS.sol";

contract DDOSBSC is IDDOS, IBEP20Ownable, ERC20PresetMinterPauser {
    
    uint public constant override INITIAL_SUPPLY = 200000 * DECIMAL_MULTIPLIER;
    uint public constant override MAX_SUPPLY = 10000000 * DECIMAL_MULTIPLIER;
    uint private constant DECIMAL_MULTIPLIER = 10**18;

    constructor() ERC20PresetMinterPauser("Disbalancer", "DDOS") public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function _mint(address account, uint amount) internal virtual override {
        require(totalSupply().add(amount) <= MAX_SUPPLY, "DDOS: MAX_SUPPLY");
        super._mint(account, amount);
    }

    function getOwner() external view override returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }
}