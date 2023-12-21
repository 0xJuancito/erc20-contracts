// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../access/Blacklistable.sol";

///@title BUMP ERC20 Token
contract BUMPTokenV2 is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    Blacklistable
{
    ///@notice Will initialize state variables of this contract
    ///@param name_- Name of ERC20 token.
    ///@param symbol_- Symbol to be used for ERC20 token.
    function initialize(
        string calldata name_,
        string calldata symbol_,
        uint256 bumpSupply
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __Pausable_init();
        __Ownable_init();
        __ERC20Permit_init(name_);
        _mint(msg.sender, bumpSupply);
        _pause();
    }

    ///@notice This function is used by governance to pause BUMP token contract.
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    ///@notice This function is used by governance to un-pause BUMP token contract.
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    ///@notice Moves `amount` tokens from the caller's account to `recipient`
    ///@param recipient- Account to which tokens are transferred
    ///@param amount- Amount of tokens transferred
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(recipient)
        returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    ///@notice Sets `amount` as the allowance of `spender` over the caller's tokens.
    ///@param spender- Account to which tokens are approved
    ///@param amount- Amount of tokens approved
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        notBlacklisted(msg.sender) 
        notBlacklisted(spender)
        returns (bool)
    {
        return super.approve(spender, amount);
    }

    ///@notice Moves `amount` tokens from `sender` to `recipient` using the allowance
    ///        mechanism. `amount` is then deducted from the caller's allowance
    ///@param sender- Account which is transferring tokens
    ///@param recipient- Account which is receiving tokens
    ///@param amount- Amount of tokens being transferred
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) 
        public 
        virtual
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(recipient) 
        notBlacklisted(sender)
        returns (bool) 
    {
        return super.transferFrom(sender, recipient, amount);
    }
}
