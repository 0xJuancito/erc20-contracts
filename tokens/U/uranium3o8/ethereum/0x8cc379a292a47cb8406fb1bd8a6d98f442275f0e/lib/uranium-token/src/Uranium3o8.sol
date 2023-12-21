// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "./Pausable.sol";
import {Blacklistable} from "./Blacklistable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Rescuable} from "./Rescuable.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Uranium3o8 Token
 * @dev ERC20 token with pausable, blacklistable, and rescuable features.
 * @notice Major powers are separated amongst the roles in the Uranium3o8 token
 *
 * Owner: Can change ownership and update contract roles.
 *   Power: can transfer Ownership, update Pauser, Rescuer, Blacklister, and MasterMinter.
 *
 * Pauser: Can pause and unpause the contract.
 *   Power: Pause and Unpause. Pausing restricts all non-view functions in the Uranium3o8 contract.
 *
 * Rescuer: Can rescue ERC20 tokens accidentally sent to the contract.
 *   Power: Rescue Funds. 
            Rescue rights not affected by pauses.
 *
 * Blacklister: Can manage the blacklist and restrict certain functions.
 *   Power: Add to and Remove from Blacklist.
 *          Blacklisted addresses face restricted functionalities.
 *          Blacklisting rights are not affected by pauses.
 *
 * Master Minter: Controls minting-related operations and configuration.
 *   Power: Issue and Redeem tokens. Configure and manage minters.
 *   The Master minter has the exclusive authority to add, update, and remove minters.
 *   Constraint: Minting and burning can only be performed by the masterMinter. 
 *   Minters' operations are subject to the allowance set by the masterMinter.
 */

contract Uranium3o8 is
    Pausable,
    Blacklistable,
    Rescuable,
    ReentrancyGuard,
    ERC20
{
    constructor() ERC20("Uranium3o8", "U") {
        masterMinter = address(msg.sender);
    }

    uint256 public maxMinterNumber;

    address public masterMinter;
    /** @notice array of all minter address */
    address[] public minterAddresses;
    /** @notice mapping to check if a given address is a minter */
    mapping(address => bool) public minters;
    /** @notice mapping of minter to its allowance */
    mapping(address => uint256) public minterAllowance;
    /** @notice mapping of minter to allowance already used */
    mapping(address => uint256) public minterUsedAllowance;

    event Issued(uint256 amount);
    event Redeemed(uint256 amount);
    event MintedByMinter(uint256 amount, uint256 usedAllowance, address minter);
    event BurnedByMinter(uint256 amount, uint256 usedAllowance, address minter);
    event MasterMinterChanged(address indexed newMasterMinter);
    event MinterConfigured(
        address indexed minter,
        uint256 minterAllowanceAmount
    );
    event MinterRemoved(address minter);
    event DestroyedBlackFunds(
        address indexed blackListedUser,
        uint256 dirtyFunds
    );
    event MaximumNumberOfMinters(uint256 newMinterNumber);

    /**
     * @dev Throws if called by any account other than a minter
     */
    modifier onlyMinters() {
        require(minters[msg.sender], "Uranium3o8: caller is not a minter");
        _;
    }

    /**
     * @dev Throws if called by any account other than the masterMinter
     */
    modifier onlyMasterMinter() {
        require(
            msg.sender == masterMinter,
            "Uranium3o8: caller is not the masterMinter"
        );
        _;
    }

    /**
     @dev checks if it is on the minterAddresses array
     * We iterate over the dynamic array and not the mapping because 
     * this is the most informationally dense structure where data on minters is stored. 
     */

    function isMinter(address minter) public view returns (bool) {
        // for (uint i = 0; i < minterAddresses.length; i++) {
        //     if (minterAddresses[i] == minter) {
        //         return true;
        //     }
        // }
        // return false;
        bool _is = minters[minter];
        return _is;
    }

    function allMinters() public view returns (address[] memory) {
        return minterAddresses;
    }

    function numberOfMinters() public view returns (uint256 mintersNumber) {
        address[] memory _minterAddresses = allMinters();
        mintersNumber = _minterAddresses.length;
        return mintersNumber;
    }

    function transfer(
        address _to,
        uint256 _value
    )
        public
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(_to)
        returns (bool)
    {
        return super.transfer(_to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        override
        whenNotPaused
        notBlacklisted(_from)
        notBlacklisted(_to)
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    /** @dev Issues a new amount of tokens.
     * These tokens are deposted into the owner address.
     * Only the masterMinter call this function.
     * Issue amount is unlimited.
     */

    function issue(
        uint256 amount
    )
        external
        nonReentrant
        onlyMasterMinter
        whenNotPaused
        notBlacklisted(msg.sender)
    {
        _mint(masterMinter, amount);
        emit Issued(amount);
    }

    /** @dev Redeems an amount of tokens.
     * These tokens are withdrawn from the owner address,
     * which means the tokens must be deposited from the owner address before hand.
     * Only the masterMinter call this function.
     * The redemption amount must be covered by the balance in the owern address
     * or the call will fail.
     */

    function redeem(
        uint256 amount
    )
        external
        nonReentrant
        onlyMasterMinter
        whenNotPaused
        notBlacklisted(msg.sender)
    {
        _burn(masterMinter, amount);
        emit Redeemed(amount);
    }

    /**
     * @notice Mint new tokens by an authorized minter.
     * MasterMinter may not call this function as masterMinter cannot be added to the list of minters
     * @param to Recipient address for minted tokens.
     * @param amount Amount of tokens to mint.
     * Requirements: Authorized minter, contract not paused, recipient not blacklisting.
     * Emits a MintedByMinter event.
     */
    function mintByMinter(
        address to,
        uint256 amount
    )
        external
        nonReentrant
        onlyMinters
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
    {
        uint256 allowance = minterAllowance[msg.sender];
        uint256 usedAllowance = minterUsedAllowance[msg.sender];
        require(usedAllowance + amount <= allowance, "Insufficient allowance");

        _mint(to, amount);
        minterUsedAllowance[msg.sender] += amount;
        emit MintedByMinter(amount, minterUsedAllowance[msg.sender], to);
    }

    /**
     * @notice Redeems tokens by an authorized minter.
     * MasterMinter may not call this function as masterMinter cannot be added to the list of minters
     * @param amount Amount of tokens to be redeemed.
     * Requirements: Authorized minter, contract not paused, recipient not blacklisting.
     * Emits a BurnedByMinter event.
     */

    function burnByMinter(
        uint256 amount
    )
        external
        nonReentrant
        onlyMinters
        whenNotPaused
        notBlacklisted(msg.sender)
    {
        uint256 usedAllowance = minterUsedAllowance[msg.sender];
        /** the minter can't burn if it has not used any of its allowance. */
        require(usedAllowance > 0, "minter has not used any of its allowance");
        /** The following basically means if a minter burns more than its usedAllownace,
         * there will be tokens left unburned,
         * and some other minter will have to burn it.
         */
        bool burningMoreThanUsedAllowance = (usedAllowance < amount);
        uint256 burningAmount = (
            burningMoreThanUsedAllowance ? usedAllowance : amount
        );
        minterUsedAllowance[msg.sender] -= burningAmount;
        _burn(msg.sender, burningAmount);
        emit BurnedByMinter(burningAmount, usedAllowance, msg.sender);
    }

    /**
     * @dev Updates the address of the masterMinter role.
     * Only the contract owner can update the masterMinter address.
     * @param _newMasterMinter The new address to be set as the masterMinter.
     * The new address cannot be the zero address and must not be blacklisted.
     * Emits a MasterMinterChanged event.
     */
    function updateMasterMinter(
        address _newMasterMinter
    )
        external
        nonReentrant
        whenNotPaused
        onlyOwner
        notBlacklisted(_newMasterMinter)
    {
        require(
            _newMasterMinter != address(0),
            "Uranium3o8: new masterMinter is the zero address"
        );
        masterMinter = _newMasterMinter;
        emit MasterMinterChanged(masterMinter);
    }

    /**
     * @dev Function to add a new minter or to update the allowance of a minter
     * @param minter The address of the minter
     * @param newMinterAllowanceAmount The minting amount allowed for the minter
     * @return True if the operation was successful.
     */
    function configureMinter(
        address minter,
        uint256 newMinterAllowanceAmount
    ) external nonReentrant whenNotPaused onlyMasterMinter returns (bool) {
        require(minter != masterMinter, "Trying to add masterMinter");
        require(
            minter != address(0),
            "Trying to add the zero address as minter!"
        );
        bool _alreadyIsMinter = isMinter(minter);
        if (!_alreadyIsMinter) {
            require(
                numberOfMinters() + 1 <= maxMinterNumber,
                "maximum number of minters reached"
            );
        }
        /** If the masterMinter reconfigures the minter's allowance
         * to something lower than the allowance it has already used,
         * the minter's usedAllowance will be reset to the new allowance,
         * which effectively means the minter will not be able to mint anymore.
         */
        uint256 oldMinterAllowanceAmount = minterAllowance[minter];
        uint256 usedAllowance = minterUsedAllowance[minter];
        if (
            newMinterAllowanceAmount <= oldMinterAllowanceAmount &&
            usedAllowance >= newMinterAllowanceAmount
        ) {
            minterUsedAllowance[minter] = newMinterAllowanceAmount;
        }

        minterAllowance[minter] = newMinterAllowanceAmount;
        if (!_alreadyIsMinter) {
            minterAddresses.push(minter);
            minters[minter] = true;
            assert(numberOfMinters() <= maxMinterNumber);
        }
        emit MinterConfigured(minter, newMinterAllowanceAmount);
        return true;
    }

    /**
     * @dev Removes a minter from the list of authorized minters.
     * Only the masterMinter can call this function to remove a minter.
     * @param minter The address of the minter to be removed.
     * @return A boolean indicating the success of the operation.
     * Requirements: Caller must be the masterMinter, contract not paused,
     * the minter address cannot be the zero address, and the minter cannot be the contract owner.
     * Emits a MinterRemoved event.
     */
    function removeMinter(
        address minter
    ) external nonReentrant whenNotPaused onlyMasterMinter returns (bool) {
        require(minter != address(0), "Zero address!");
        require(isMinter(minter), "Address not on list of minter addresses!");
        // deleting value from mapping
        delete minters[minter];
        delete minterAllowance[minter];
        delete minterUsedAllowance[minter];

        // Find and remove the minter from the list of minter addresses
        for (uint256 i = 0; i < minterAddresses.length; i++) {
            // if the programme finds a slot in the array whose entry is the minter
            // it replaces it with the last element in the array
            if (minterAddresses[i] == minter) {
                minterAddresses[i] = minterAddresses[
                    minterAddresses.length - 1
                ];
                minterAddresses.pop();
                break;
            }
        }
        emit MinterRemoved(minter);
        return true;
    }

    /** @dev called by owner to configure the maximum number of minters
     * Not in the hands of the masterMinter to separate powers.
     */
    function setMaximumNumberOfMinters(
        uint256 minterNumber
    ) external onlyOwner {
        maxMinterNumber = minterNumber;
        emit MaximumNumberOfMinters(minterNumber);
    }

    /**
     * @dev this function destroys the balance of a blacklisted address.
     * The function is callable only by the masterMinter and not the blacklister.
     * This is to concentrate the rights concerning supply change in the hands of the masterMinter.
     * And to deprive the blacklister of independent and unchecked fund destruction powers.
     */
    function destroyBlackFunds(
        address _blackListedUser
    ) external nonReentrant onlyMasterMinter {
        require(isBlacklisted[_blackListedUser], "user is not blacklisted!");
        uint256 dirtyFunds = balanceOf(_blackListedUser);
        _burn(_blackListedUser, dirtyFunds);
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }
}
