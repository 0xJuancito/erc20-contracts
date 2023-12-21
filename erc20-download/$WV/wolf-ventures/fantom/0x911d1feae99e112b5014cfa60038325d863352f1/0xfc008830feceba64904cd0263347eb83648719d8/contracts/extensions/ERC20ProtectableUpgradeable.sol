// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Extension of {ERC20} that allows token to be protected from bots
 */
abstract contract ERC20ProtectableUpgradeable is Initializable, ContextUpgradeable, ERC20Upgradeable {
    uint256 public maxBuyAmount;
    uint256 public maxSellAmount;
    uint256 public maxWallet;
    uint256 public swapTokensAtAmount;
    uint256 public blockForPenaltyEnd;
    uint256 public tradingActiveBlock; // 0 means trading is not active
    uint256 public botsCaught;
    bool public limitsInEffect;
    bool public sellingEnabled; // MEV Bot prevention - cannot be turned off once enabled!!
    bool public tradingActive;
    bool public transferFeesEnabled;
    address[] public earlyBuyers;

    mapping(address => bool) public boughtEarly;
    mapping(address => bool) private _isExcludedMaxTransactionAmount;

    //Events..
    event MaxTransactionExclusion(address _address, bool excluded);
    event EnabledSellingForever();
    event EnabledTrading();
    event CaughtEarlyBuyer(address sniper);

    //End Events

    function __ERC20Protectable_init() internal onlyInitializing {
        __ERC20Protectable_init_unchained();
    }

    function __ERC20Protectable_init_unchained() internal onlyInitializing {
        tradingActiveBlock = 0;
        limitsInEffect = true;
        tradingActive = false;
        transferFeesEnabled = false;
        maxBuyAmount = (totalSupply() * 15) / 1000;
        // 1.5%
        maxSellAmount = (totalSupply() * 15) / 1000;
        // 1.5%
        maxWallet = (totalSupply() * 15) / 1000;
        // 1.5%
        swapTokensAtAmount = (totalSupply() * 5) / 10000;
        // 0.05 %
    }

    function _getEarlyBuyers() internal view returns (address[] memory) {
        return earlyBuyers;
    }

    function _removeBoughtEarly(address wallet) internal virtual {
        require(boughtEarly[wallet], "Wallet is already not flagged.");
        boughtEarly[wallet] = false;
    }

    function _markBoughtEarly(address wallet) internal virtual {
        require(!boughtEarly[wallet], "Wallet is already flagged.");
        boughtEarly[wallet] = true;
    }

    function _excludeFromMaxTransaction(address walletAddress, bool isExcluded) internal virtual {
        _isExcludedMaxTransactionAmount[walletAddress] = isExcluded;
        emit MaxTransactionExclusion(walletAddress, isExcluded);
    }

    function earlyBuyPenaltyInEffect() internal view virtual returns (bool) {
        return block.number < blockForPenaltyEnd;
    }

    // remove limits after token is stable
    function _removeLimits() internal virtual {
        limitsInEffect = false;
    }

    function _restoreLimits() internal virtual {
        limitsInEffect = true;
    }

    // Enable selling - cannot be turned off!
    function _setSellingEnabled(bool confirmSellingEnabled) internal virtual {
        require(confirmSellingEnabled, "Confirm selling enabled!");
        require(!sellingEnabled, "Selling already enabled!");

        sellingEnabled = true;
        emit EnabledSellingForever();
    }

    // change the minimum amount of tokens to sell from fees
    function _updateSwapTokensAtAmount(uint256 newAmount) internal virtual {
        require(newAmount >= (totalSupply() * 1) / 100000, "Swap amount cannot be lower than 0.001% total supply.");
        require(newAmount <= (totalSupply() * 1) / 1000, "Swap amount cannot be higher than 0.1% total supply.");
        swapTokensAtAmount = newAmount;
    }

    function _startTrading(uint256 blocksForPenalty) internal {
        require(!tradingActive, "Cannot reenable trading");
        require(blocksForPenalty <= 10, "Cannot make penalty blocks more than 10");
        tradingActive = true;
        transferFeesEnabled = true;
        tradingActiveBlock = block.number;
        blockForPenaltyEnd = tradingActiveBlock + blocksForPenalty;
        emit EnabledTrading();
    }

    function getIsExcludedFromMaxAmount(address wallet) internal view returns (bool) {
        return _isExcludedMaxTransactionAmount[wallet];
    }

    function triggerBotCought(address to) internal {
        boughtEarly[to] = true;
        botsCaught += 1;
        earlyBuyers.push(to);
        emit CaughtEarlyBuyer(to);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
