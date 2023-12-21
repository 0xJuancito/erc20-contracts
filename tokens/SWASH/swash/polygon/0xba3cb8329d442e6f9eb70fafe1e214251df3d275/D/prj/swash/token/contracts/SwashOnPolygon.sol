// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./ERC677.sol";
import "./IERC677Receiver.sol";


contract SwashOnPolygon is ERC677, ERC20Permit, ERC20Burnable, Ownable {
    address public childChainManager ;

    constructor(address initialChildChainManager )  ERC20("Swash Token", "SWASH") ERC20Permit("SWASH")  {
        setChildChainManager (initialChildChainManager );
    }

    function setChildChainManager (address newChildChainManager) public onlyOwner {
        childChainManager  = newChildChainManager;
    }

    /**
     * When tokens are bridged from mainnet, perform a "mint" and "transferAndCall" to activate
     *   the receiving contract's ERC677 onTokenTransfer callback
     * Equal amount of tokens got locked in ChildChainManager on the mainnet side
     */
    function deposit(address user, bytes calldata depositData) external {
        require(_msgSender() == childChainManager , "error_onlyBridge");
        uint256 amount = abi.decode(depositData, (uint256));

        // emits two Transfer events: 0x0 -> childChainManager  -> user
        _mint(childChainManager , amount);
        transferAndCall(user, amount, depositData);
    }

    /**
     * When returning to mainnet, it's enough to simply burn the tokens on the Polygon side
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}