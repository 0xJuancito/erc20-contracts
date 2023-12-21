// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract wGameStationToken is ERC20, Pausable, Ownable {
    address public bridgeAddress;

    modifier onlyBridge() {
        require(
            _msgSender() == bridgeAddress,
            "Ownable: caller is not the bridge"
        );
        _;
    }

    constructor(address bridgeContract_) ERC20("GameStation", "GAMER") {
        bridgeAddress = bridgeContract_;
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setBridgeAddress(address bridgeAddress_) external onlyOwner {
        bridgeAddress = bridgeAddress_;
    }

    function mint(address recipient_, uint256 amount_) external onlyBridge {
        _mint(recipient_, amount_);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
