// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "./Governable.sol";

/**
 * @title PEN governance token
 * @author Penrose
 */
contract Pen is ERC20, Governable, ERC20Permit, ERC20FlashMint {
    address public minterAddress;

    constructor() ERC20("PEN", "PEN") ERC20Permit("PEN") {}

    modifier onlyMinter() {
        require(
            msg.sender == minterAddress,
            "Ownable: caller is not the minter"
        );
        _;
    }

    function setMinter(address _minterAddress) public onlyGovernance {
        minterAddress = _minterAddress;
    }

    function mint(address to, uint256 amount) public onlyMinter {
        _mint(to, amount);
    }
}
