// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Extension of {ERC20} that allows token to have fees
 */
abstract contract ERC20FeesableUpgradeable is Initializable, ContextUpgradeable, ERC20Upgradeable {
    mapping(address => bool) private _isExcludedFromFees;

    //Events..
    event ExcludeFromFees(address indexed account, bool isExcluded);

    //End Events

    uint256 private maxFee;
    uint256 private buyFees;
    uint256 private sellFees;
    uint256 private originalBuyFee;
    uint256 private originalSellFee;

    uint256 public buyTreasuryFee;
    uint256 public buyBurnFee;

    uint256 private originalTreasuryFee;
    uint256 private originalBurnFee;

    uint256 public sellTreasuryFee;
    uint256 public sellBurnFee;


    modifier whenNotMaxFees(uint256 fee) {
        require(fee <= maxFee, "Must keep fees at 10% or less");
        _;
    }

    function __ERC20Feesable_init(uint256 burnFee, uint256 treasuryFee, uint256 maxFees) internal onlyInitializing {
        __ERC20Feesable_init_unchained(burnFee, treasuryFee, maxFees);
    }

    function __ERC20Feesable_init_unchained(uint256 burnFee, uint256 treasuryFee, uint256 maxFees) internal onlyInitializing {
        originalBuyFee = burnFee + treasuryFee;
        originalSellFee = burnFee + treasuryFee;
        maxFee = maxFees;
        buyFees = originalBuyFee;
        sellFees = originalSellFee;

        buyTreasuryFee = treasuryFee;
        sellTreasuryFee = treasuryFee;

        buyBurnFee = burnFee;
        sellBurnFee = burnFee;
    }

    function _updateBuyFees(uint256 treasuryFee, uint256 burnFee) internal virtual whenNotMaxFees((treasuryFee + burnFee)) {
        buyFees = treasuryFee + burnFee;
        buyTreasuryFee = treasuryFee;
        buyBurnFee = burnFee;
    }

    function _updateSellFees(uint256 treasuryFee, uint256 burnFee) internal virtual whenNotMaxFees((treasuryFee + burnFee)) {
        sellFees = treasuryFee + burnFee;
        sellTreasuryFee = treasuryFee;
        sellBurnFee = burnFee;
    }

    function _excludeFromFees(address account, bool excluded) internal virtual {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function _resetTaxes() internal virtual {
        buyFees = originalBuyFee;
        sellFees = originalSellFee;

        buyBurnFee = originalBurnFee;
        sellBurnFee = originalBurnFee;

        buyTreasuryFee = originalTreasuryFee;
        sellTreasuryFee = originalTreasuryFee;
    }

    function _calculateBotFees(uint256 amount) internal view returns  (uint256 , uint256 , uint256 ) {
        uint256 fees = (amount * 99) / 100;
        uint256 tokensForTreasury = (fees * buyTreasuryFee) / buyFees;
        uint256 tokensForBurn = (fees * buyBurnFee) / buyFees;
        return (fees,tokensForTreasury,tokensForBurn);
    }

    function _calculateSellFees(uint256 amount) internal view returns (uint256 , uint256 , uint256 ){
        uint256 fees = (amount * sellFees) / 100;
        uint256 tokensForTreasury = (fees * sellTreasuryFee) / sellFees;
        uint256 tokensForBurn = (fees * sellBurnFee) / sellFees;
        return (fees,tokensForTreasury,tokensForBurn);
    }

    function _calculateBuyFees(uint256 amount) internal view returns (uint256 , uint256 , uint256 ) {
        uint256 fees = (amount * buyFees) / 100;
        uint256 tokensForTreasury = (fees * buyTreasuryFee) / buyFees;
        uint256 tokensForBurn = (fees * buyBurnFee) / buyFees;
        return (fees,tokensForTreasury,tokensForBurn);
    }

    function getIsExcludedFromFee(address wallet) internal view returns (bool){
        return _isExcludedFromFees[wallet];
    }

    function getBuyFee() internal view returns (uint256) {return buyFees;}

    function getSellFee() internal view returns (uint256) {return sellFees;}
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
