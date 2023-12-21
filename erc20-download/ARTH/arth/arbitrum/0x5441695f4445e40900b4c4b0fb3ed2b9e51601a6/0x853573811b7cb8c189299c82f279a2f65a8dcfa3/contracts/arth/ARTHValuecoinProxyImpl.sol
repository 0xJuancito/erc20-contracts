// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/ERC20.sol";
import "../lib/Ownable.sol";
import "../lib/Pausable.sol";
import "../lib/ERC20Permit.sol";
import "../proxy/VersionedInitializable.sol";

/**
 * Implementation of the ARTH token as a proxy contract for layer 2 chains
 */
contract ARTHValuecoinProxyImpl is
    VersionedInitializable,
    ERC20,
    Pausable,
    ERC20Permit,
    Ownable
{
    function initialize(address owner) external payable initializer {
        initializeERC20("ARTH Valuecoin", "ARTH");
        initializePausable();
        initializeOwnable(owner);
        initializeERC20Permit("ARTH");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(address(to) != address(this), "dont send to token contract");
        require(!paused(), "ERC20Pausable: token transfer while paused");
    }

    function burn(uint256 _amount) external {
        _burn(_msgSender(), _amount);
    }

    function burnFrom(address who, uint256 _amount) external onlyOwner {
        _burn(who, _amount);
    }

    function togglePause() external onlyOwner {
        if (!paused()) _pause();
        else _unpause();
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 0;
    }
}
