// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @custom:security-contact security@aubit.io
contract FreewayToken is Initializable, ERC20Upgradeable, PausableUpgradeable, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    mapping(address => bool) private _blacklist;

    function initialize() external initializer {
        __ERC20_init("FreewayToken", "FWT");
        __Pausable_init();
        __Ownable_init();

        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        require (to != address(this), "Token transfers to the contract address are forbidden");
        require (!isBlackListed(from), "Token transfer refused. from is on blacklist");
        super._beforeTokenTransfer(from, to, amount);
    }
    
    event BlacklistUpdated(address indexed user, bool value);

    function blacklistUpdate(address user, bool value) public virtual onlyOwner {
        _blacklist[user] = value;
        emit BlacklistUpdated(user, value);
    }
    
    function isBlackListed(address user) public view returns (bool) {
        return _blacklist[user];
    }

    /**
    * @dev For a large number of destinations, separate in different calls to batchTransfer.
    * @param destinations List of addresses to set the values
    * @param values List of values to set
    */
    function batchTransfer(address[] calldata destinations, uint256[] calldata values) external {
        require(destinations.length == values.length, "destinations.length != values.length");
        
        uint256 length = destinations.length;
        uint i;
        
        for (i = 0; i < length; i++) {
            _transfer(msg.sender, destinations[i], values[i]);
        }
    }

    /**
     * @dev Remember that only owner can call so be careful when use on contracts generated from other contracts.
     * @param tokenAddress The token contract address
     * @param tokenAmount Number of tokens to be sent
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public virtual onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
}
