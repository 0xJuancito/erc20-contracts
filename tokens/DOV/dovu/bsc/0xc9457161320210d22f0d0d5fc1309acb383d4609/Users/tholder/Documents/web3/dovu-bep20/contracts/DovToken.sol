pragma solidity ^0.6.0;

import "./BEP20/BEP20Blockable.sol";
import "./BEP20/BEP20Capped.sol";
import "./BEP20/BEP20PresetMinterPauser.sol";

contract DovToken is BEP20PresetMinterPauser, BEP20Capped, BEP20Blockable {
    constructor (string memory name, string memory symbol, uint256 cap) public BEP20PresetMinterPauser(name, symbol) BEP20Capped(cap) {}

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(BEP20PresetMinterPauser, BEP20Capped, BEP20Blockable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
