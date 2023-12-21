// SPDX-License-Identifier: MIT

/*
    __     __        ______  __     __  ________ 
  _|  \_  |  \      |      \|  \   |  \|        \
 /   $$ \ | $$       \$$$$$$| $$   | $$| $$$$$$$$
|  $$$$$$\| $$        | $$  | $$   | $$| $$__    
| $$___\$$| $$        | $$   \$$\ /  $$| $$  \   
 \$$    \ | $$        | $$    \$$\  $$ | $$$$$   
 _\$$$$$$\| $$_____  _| $$_    \$$ $$  | $$_____ 
|  \__/ $$| $$     \|   $$ \    \$$$   | $$     \
 \$$    $$ \$$$$$$$$ \$$$$$$     \$     \$$$$$$$$
  \$$$$$$                                        
    \$$                                          

  [Website]         https://www.livestreambets.gg
  [Twitter/X]       https://twitter.com/livestreambets
  [Telegram]        https://t.me/livestreambetsgg
*/

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LivestreambetsToken is ERC20, Ownable {
    mapping(address => bool) public isTaxExempt;
    mapping(address => bool) public isBlacklisted;

    uint256 public tax;
    address public pair;
    address public taxManager;
    address public taxRecipient;

    bool public blacklistEnabled;
    bool public sizeLimitEnabled;
    uint256 public minHoldingAmount;
    uint256 public maxHoldingAmount;

    modifier onlyOwnerOrTaxManager() {
        require(
            msg.sender == owner() || msg.sender == taxManager,
            "Caller is neither the owner nor tax manager"
        );
        _;
    }

    error NotAllowed();
    error InvalidConfig();

    constructor(
        address mintRecipient_,
        address taxRecipient_,
        address taxManager_,
        uint256 tax_
    ) ERC20("Livestreambets", "LIVE") {
        _mint(mintRecipient_, 777_777_777 * 10 ** decimals());
        setTaxRecipient(taxRecipient_);
        setTaxManager(taxManager_);
        setTax(tax_);

        setTaxExempt(msg.sender, true);
        setTaxExempt(taxManager, true);
        setTaxExempt(taxRecipient, true);
    }

    function setPair(address pair_) external onlyOwner {
        pair = pair_;
    }

    function setTaxRecipient(
        address taxRecipient_
    ) public onlyOwnerOrTaxManager {
        if (taxRecipient_ == address(0)) {
            revert InvalidConfig();
        }
        taxRecipient = taxRecipient_;
    }

    function setTaxManager(address taxManager_) public onlyOwner {
        if (taxManager_ == address(0)) {
            revert InvalidConfig();
        }
        taxManager = taxManager_;
    }

    function setTax(uint256 tax_) public onlyOwnerOrTaxManager {
        if (tax_ > 25) {
            revert InvalidConfig();
        }
        tax = tax_;
    }

    function setTaxExempt(
        address account_,
        bool isTaxExempt_
    ) public onlyOwnerOrTaxManager {
        isTaxExempt[account_] = isTaxExempt_;
    }

    function shouldTakeTax(
        address sender,
        address recipient
    ) public view returns (bool) {
        return
            !isTaxExempt[sender] &&
            !isTaxExempt[recipient] &&
            sender != owner() &&
            recipient != owner() &&
            pair != address(0) &&
            (sender == pair || recipient == pair);
    }

    function setIsBlacklisted(
        address account_,
        bool isBlacklisted_
    ) public onlyOwner {
        isBlacklisted[account_] = isBlacklisted_;
    }

    function setBlacklistEnabled(bool blacklistEnabled_) external onlyOwner {
        blacklistEnabled = blacklistEnabled_;
    }

    function setSizeLimitEnabled(bool sizeLimitEnabled_) external onlyOwner {
        sizeLimitEnabled = sizeLimitEnabled_;
    }

    function setSizeLimits(
        uint256 minHoldingAmount_,
        uint256 maxHoldingAmount_
    ) external onlyOwner {
        if (minHoldingAmount_ > maxHoldingAmount_) {
            revert InvalidConfig();
        }
        minHoldingAmount = minHoldingAmount_;
        maxHoldingAmount = maxHoldingAmount_;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (
            blacklistEnabled &&
            (isBlacklisted[sender] || isBlacklisted[recipient])
        ) {
            revert NotAllowed();
        }

        if (
            sizeLimitEnabled &&
            sender == pair &&
            (balanceOf(recipient) + amount > maxHoldingAmount ||
                balanceOf(recipient) + amount < minHoldingAmount)
        ) {
            revert NotAllowed();
        }

        if (shouldTakeTax(sender, recipient)) {
            uint256 taxAmount = (amount * tax) / 100;
            super._transfer(sender, recipient, amount - taxAmount);
            super._transfer(sender, taxRecipient, taxAmount);
            return;
        } else {
            super._transfer(sender, recipient, amount);
            return;
        }
    }
}
