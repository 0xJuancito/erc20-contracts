// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface _AntiBotContract {
    function applyAntiBot(address sender, address recipient, uint256 amount) external;
}

contract GamiumToken is ERC20Capped, Ownable, Pausable {
    // Antibot object
    _AntiBotContract antiBotContract;
    bool private antiBotEnabled;

    // minter address
    address public minter;

    // events
    event TokensMinted(address _to, uint256 _amount);
    event LogNewMinter(address _minter);

    // max total Supply to be minted
    uint256 private _capToken = 50 * 10 ** 9 * 1e18;

    constructor() ERC20("Gamium", "GMM") ERC20Capped(_capToken) {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Throws if called by any account other than the minter.
     */
    modifier onlyMinter() {
        require(_msgSender() != address(0), "GamiumToken: minting from the zero address");
        require(_msgSender() == minter, "GamiumToken: Caller is not the minter");
        _;
    }
    
    /**
     * @param newMinter The address of the new minter.
     */
    function setMinter(address newMinter) external onlyOwner {
        require(newMinter != address(0), "GamiumToken: Cannot set zero address as minter.");
        minter = newMinter;
        emit LogNewMinter(minter);
    }
    
    /**
     * @dev minting function.
     *
     * Emits a {TokensMinted} event.
     */
    function mint(address to, uint256 amount) external onlyMinter {
        super._mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @param status The status of the antibot.
     */
    function setAntiBot(bool status) external onlyOwner {
        antiBotEnabled = status;
    }

    /**
     * @param antiBotAddress The address of the antibot.
     */
    function setAntiBotAddress(address antiBotAddress) external onlyOwner {
        antiBotContract = _AntiBotContract(antiBotAddress);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        if (antiBotEnabled) {
            // call antibot contract
            antiBotContract.applyAntiBot(from, to, amount);
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}