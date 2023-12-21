// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./SecuredTransfer.sol";

contract MBMXToken is ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable {

    // coin owner
    string public constant coinOwner = "metalbacked.money";

    // start coins
    uint256 public constant startCoins = 10000000 * 10**18;
    
    // freeze accounts mapping
    mapping(address => bool) public frozen;
    
    // safe transfer contract
    SecuredTransfer public safeTransfer;

    /**
     * @dev Initializes the contract minting 10000000 coin to owner.
    */
    function initialize(
        string memory name_, 
        string memory symbol_
    )
    public initializer 
    {
        __Context_init();
        __Ownable_init();
        __Pausable_init();
        __ERC20_init(name_, symbol_);

        // creating safe transfer instance 
        safeTransfer = new SecuredTransfer(address(this));

        // minting starting coins
        _mint(address(this), startCoins);
    }


    /**
     * @dev airdrop the coins to accounts
     * @param accounts array of accounts
     * @param counts array of counts of coins
    */
    function airdrop(address[] calldata accounts, uint256[] calldata counts) external whenNotPaused onlyOwner {
        require(accounts.length == counts.length, "MBMXToken: invalid Data lengths mismatch");

        for (uint256 i = 0; i < accounts.length; ++i) {
            require(accounts[i] != address(0), "MBMXToken: zero address included");
            _transfer(address(this), accounts[i], counts[i]);
        }
    }

    // modifier to give access on some actions only not freezed accounts
    modifier whenNotFrozen(address from, address to) {
        require(frozen[from] == false && frozen[to] == false, "MBMXToken: account is frozen");
        _;
    }

    /**
     * @dev freezes the accounts, forbids them transfers
     * @param accounts array of accounts
    */
    function freeze(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; ++i) {
            require(accounts[i] != address(0), "MBMXToken: null address should not be in this list");
            frozen[accounts[i]] = true;
        }
    }

    /**
     * @dev unfreezes the accounts
     * @param accounts array of accounts
    */
    function unFreeze(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; ++i) {
            frozen[accounts[i]] = false;
        }
    }

    /**
     * @dev pausing the contract, where transfers or minting will be retricted
    */
    function pause() external onlyOwner {
        _pause();
    }


    /**
     * @dev unpausing the contract, where transfers or minting will be possible
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev overriding before token transfer from ERC20 contract, adding whenNotPaused modifier to restrict transfers while paused.
    */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    whenNotFrozen(from, to)
    whenNotPaused
    override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev sending coins safe on to address
     * @param to receiver address
     * @param amount amount of coins
     * @param msgHash hash of message
    */
    function sendSecured(address to, uint256 amount, bytes32 msgHash) external {
        transfer(address(safeTransfer), amount);
        safeTransfer.sendSecured(to, msg.sender, amount, msgHash);
    }

    /**
     * @dev claiming coins
     * @param from sender address
     * @param amount amount of coins
     * @param code secret code
    */
    function claim(address from, uint256 amount, uint256 code) 
    external 
    {
        safeTransfer.claim(from, msg.sender, amount, code);
    }

    /**
     * @dev get users received transfers
     * @param to receiver address
    */
    function getUserClaimTransfers(address to) public view returns (transactionInfo[] memory) {
        return safeTransfer.getUserClaimTransfers(to);
    }

    /**
     * @dev get user's sended transfers
     * @param from sender address
    */
    function getUserSentTransfers(address from) public view returns (transactionInfo[] memory) {
        return safeTransfer.getUserSentTransfers(from);
    }

    /**
     * @dev revoke safe transfer transaction
     * @param msgHash hash of transfer
    */
    function revertTransfer(bytes32 msgHash) external {
        safeTransfer.revertTransfer(msg.sender, msgHash);
    }
}
