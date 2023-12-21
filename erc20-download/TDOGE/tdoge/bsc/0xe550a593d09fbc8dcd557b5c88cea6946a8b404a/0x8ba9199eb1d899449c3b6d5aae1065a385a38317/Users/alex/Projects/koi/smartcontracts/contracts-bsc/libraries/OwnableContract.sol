// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

// import "../../3rdParty/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

// File: openzeppelin-solidity/contracts/ownership/Claimable.sol

/**
 * @title Claimable
 * @dev Extension for the Ownable contract, where the ownership needs to be claimed.
 * This allows the new owner to accept the transfer.
 */

contract OwnableContract is Initializable, ContextUpgradeable,ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address public pendingOwner;
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function initializeOwnable(address owner) internal initializer {
        __Context_init_unchained();
        require(owner != address(0), "Ownable: new owner is the zero address");
        _owner = owner;
        emit OwnershipTransferred(address(0), owner);
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }
    /**
     * @dev confirms to BEP20
     */
    function getOwner() external view returns (address){
        return _owner;
    }
    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */
    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner);
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        pendingOwner = newOwner;
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnershipImmediately(address newOwner) public onlyOwner {
        require(address(0)!=newOwner,"not allowed to transfer owner to address(0)");
        _owner = newOwner;
        emit OwnershipTransferred(_owner, newOwner);
    }
    /**
     * @dev Allows the pendingOwner address to finalize the transfer.
     */
    function claimOwnership() public onlyPendingOwner {
        emit OwnershipTransferred(_owner, pendingOwner);
        _owner = pendingOwner;
        pendingOwner = address(0);
    }
    // File: openzeppelin-solidity/contracts/ownership/CanReclaimToken.sol

    /**
    * @title Contracts that should be able to recover tokens
    * @author SylTi
    * @dev This allow a contract to recover any ERC20 token received in a contract by transferring the balance to the contract owner.
    * This will prevent any accidental loss of tokens.
    */
    /**
     * @dev Reclaim all IERC20 compatible tokens
     * @param _token IERC20 The address of the token contract
     */
    function reclaimToken(IERC20Upgradeable _token) public virtual onlyOwner {
        uint256 balance = _token.balanceOf(address(this));
        _token.safeTransfer(owner(), balance);
    }
    
    uint256[49] private __gap;
} 
