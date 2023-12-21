// SPDX-License-Identifier: MIT
/*           
   _____          __    _________                 ________  .__         
  /  _  \________/  |_  \_   ___ \_____    ____   \______ \ |__| ____   
 /  /_\  \_  __ \   __\ /    \  \/\__  \  /    \   |    |  \|  |/ __ \  
/    |    \  | \/|  |   \     \____/ __ \|   |  \  |    `   \  \  ___/  
\____|__  /__|   |__|    \______  (____  /___|  / /_______  /__|\___> 
        \/                      \/     \/     \/          \/                                           
*/
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/// @custom:security-contact keir@thinklair.com
contract DIE is ERC20, ERC20Burnable, Pausable, Ownable, ERC20Permit, ERC20Votes {
    constructor() ERC20("Art Can Die", "DIE") ERC20Permit("Art Can Die") {
        _mint(msg.sender, 21000000 * 10**decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
