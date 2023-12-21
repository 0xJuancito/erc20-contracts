// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FTC is ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 1 * 10**8 * 1e18;
    uint256 public constant MIN_BALANCE = 1 * 1e14;
    bool public isInit = false;

    address public communityFundAddr;
    address public marketAddr;
    mapping(address => bool) private _isExcludedFromFee;

    constructor() public ERC20("Fintoken Coin", "FTC") {}

    function initSupply(
        address _presaleAddr,
        address _liquidityAddr,
        address _communityAddr,
        address _devAddr,
        address _dexAddr
    ) external onlyOwner {
        require(!isInit, "inited");
        isInit = true;
        _mint(_presaleAddr, (MAX_SUPPLY * 25) / 100);
        _mint(_liquidityAddr, (MAX_SUPPLY * 25) / 100);
        _mint(_communityAddr, (MAX_SUPPLY * 40) / 100);
        _mint(_devAddr, (MAX_SUPPLY * 5) / 100);
        _mint(_dexAddr, (MAX_SUPPLY * 5) / 100);
    }

    function setFeeAddrs(address _communityFundAddr, address _marketAddr)
        external
        onlyOwner
    {
        require(_communityFundAddr != address(0) && _marketAddr != address(0));
        communityFundAddr = _communityFundAddr;
        marketAddr = _marketAddr;
    }

    function setExcludeFromFee(address account, bool enable)
        external
        onlyOwner
    {
        if(_isExcludedFromFee[account] != enable) {
            _isExcludedFromFee[account] = enable;
        }
    }

    function multiTransfer(address[] memory receivers, uint256[] memory amounts)
        external
    {
        require(
            receivers.length == amounts.length,
            "The length of receivers and amounts is not matched"
        );
        for (uint256 i = 0; i < receivers.length; i++) {
            transfer(receivers[i], amounts[i]);
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            amount <= balanceOf(sender),
            "ERC20: transfer amount exceeds balance"
        );
        require(
            balanceOf(sender) > MIN_BALANCE,
            "balance must be greater than min_balance"
        );
        if (!_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient]) {
            if (balanceOf(sender) - amount < MIN_BALANCE) {
                amount -= MIN_BALANCE;
            }

            uint256 communityFundAmount = (amount * 2) / 100;
            uint256 marketAmount = amount / 100;

            uint256 transferTokenAmount = amount -
                communityFundAmount -
                marketAmount;

            super._transfer(sender, communityFundAddr, communityFundAmount);
            super._transfer(sender, marketAddr, marketAmount);
            super._transfer(sender, recipient, transferTokenAmount);
        } else {
            super._transfer(sender, recipient, amount);
        }
    }
}
