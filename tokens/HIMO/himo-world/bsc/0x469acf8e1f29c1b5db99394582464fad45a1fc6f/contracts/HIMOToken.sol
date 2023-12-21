// contracts/HIMOToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IBPContract {
    function protect(
        address from,
        address to,
        uint256 amount
    ) external;
}

contract HIMOToken is ERC20, Pausable, Ownable {
    IBPContract public BP;
    bool public bpEnabled;

    event BPAdded(address indexed bp);
    event BPEnabled(bool indexed _enabled);
    event BPTransfer(address from, address to, uint256 amount);

    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Disable the {transfer} functions of contract.
     *
     * Can only be called by the current owner.
     * The contract must not be paused.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Enable the {transfer} functions of contract.
     *
     * Can only be called by the current owner.
     * The contract must be paused.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    function setBpAddress(address _bp) external onlyOwner {
        BP = IBPContract(_bp);

        emit BPAdded(_bp);
    }

    function setBpEnabled(bool _enabled) external onlyOwner {
        require(address(BP) != address(0), "You have to set BP address first");
        bpEnabled = _enabled;
        emit BPEnabled(_enabled);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");

        if (bpEnabled) {
            BP.protect(from, to, amount);
            emit BPTransfer(from, to, amount);
        }
    }
}
