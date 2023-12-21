// contracts/AurusX_Polygon.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract AurusX_Polygon is ERC20PausableUpgradeable, OwnableUpgradeable {

    address public childChainManagerProxy;

    event ForceTransfer(address indexed from, address indexed to, uint256 value, bytes32 details);

    function initialize(string memory name_, string memory symbol_) public initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init_unchained();
    }    

    /*
     * Pause transfers
     */
    function pauseTransfers() external onlyOwner {
        _pause();
    }    

    /*
     * Resume transfers
     */
    function resumeTransfers() external onlyOwner {
        _unpause();
    }

    /*
     * Force transfer callable by owner (governance).
     */ 
    function forceTransfer(address sender_, address recipient_, uint256 amount_, bytes32 details_) external onlyOwner {
        _burn(sender_,amount_);
        _mint(recipient_,amount_);
        emit ForceTransfer(sender_, recipient_, amount_, details_);
    }    

    /**
     * Update the childChainManagerProxy
     */
    function updateChildChainManager(address newChildChainManagerProxy) external onlyOwner {
        _updateChildChainManager(newChildChainManagerProxy);
    }

    /**
     * Function call be called by chain manager (Polygon)
     */
    function deposit(address user, bytes calldata depositData) external {
        _deposit(user, depositData);
    }
    
    /**
     * Function call be called by chain manager (Polygon)
     */
    function withdraw(uint256 amount) external {
        _withdraw(amount);
    }    

    // being proxified smart contract, most probably childChainManagerProxy contract's address
    // is not going to change ever, but still, lets keep it 
    function _updateChildChainManager(address newChildChainManagerProxy) internal {
        require(newChildChainManagerProxy != address(0), "Bad ChildChainManagerProxy address");
        childChainManagerProxy = newChildChainManagerProxy;
    }

    function _deposit(address user, bytes calldata depositData) internal {
        require(msg.sender == childChainManagerProxy, "You're not allowed to deposit");

        uint256 amount = abi.decode(depositData, (uint256));

        // `amount` token getting minted here & equal amount got locked in RootChainManager
        _mint(user,amount);
    }

    function _withdraw(uint256 amount) internal {
        _burn(msg.sender, amount);
    }    
}
