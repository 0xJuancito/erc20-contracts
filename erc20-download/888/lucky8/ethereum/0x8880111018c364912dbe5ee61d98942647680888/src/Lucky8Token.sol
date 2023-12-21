// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.21;

import { console2 } from "forge-std/console2.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IUniswapV2Pair } from "./uniswap/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "./uniswap/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "./uniswap/IUniswapV2Router.sol";

/// @dev The Lucky8Token contract.
contract Lucky8Token is ERC20, Ownable {
    ///////////////////////////////////////////
    //////// CONSTANTS AND IMMUTABLES /////////
    ///////////////////////////////////////////

    /// @dev Dead address.
    address internal constant _ZERO_ADDR = address(0);

    /// @dev Uniswap V2 USDC Pair.
    address public pair;

    /// @dev Uniswap V2 Router.
    IUniswapV2Router02 public immutable uniswapV2Router;

    ///////////////////////////////////////////
    //////// TOKEN SETTINGS ///////////////////
    ///////////////////////////////////////////

    /// @dev Buy fee.
    uint256 public buyFee = 10;

    /// @dev Sell fee.
    uint256 public sellFee = 10;

    /// @dev The max transaction amount (percentage of total supply).
    uint256 public maxTxAmount = 1_000_000 ether;

    /// @dev The max balance a wallet can have.
    uint256 public maxWalletBalance = 5_000_000 ether;

    /// @dev This is the address that will receive all fees.
    address public feeWallet;

    /// @dev This enables or disables the blocklist.
    bool public isBlocklistEnabled = true;

    /// @dev This enables or disables limits on transfers.
    bool public limitsEnabled = true;

    /// @dev In case we need to lock any whales or bad actors.
    mapping(address => bool) public isBlocked;

    /// @dev Stores AMMs pairs.
    mapping(address => bool) public isAmmPair;

    // @dev Stores addresses that can transfer before trading.
    mapping(address => bool) public canTransferBeforeTrading;

    /// @dev Stores addresses that are excluded from fees.
    mapping(address => bool) public isExcludedFromFee;

    /// @dev Stores addresses that are excluded from max transaction amount.
    mapping(address => bool) public isExcludedFromMaxTx;

    /// @dev Stores addresses that are excluded from max wallet balance.
    mapping(address => bool) public isExcludedFromMaxPerWallet;

    ///////////////////////////////////////////
    //////// EVENTS ///////////////////////////
    ///////////////////////////////////////////

    /// @dev This event is emitted when the blocklist is enabled or disabled.
    event SetBlocklistEnabled(bool enabled);

    /// @dev This event is emitted when an address is added to the list of addresses that can transfer
    ///      before trading is enabled.
    event SetCanTransferBeforeTrading(address addr, bool blocked);

    /// @dev This event is emitted when an address is blocked or unblocked.
    event SetBlockedAddress(address addr, bool blocked);

    /// @dev This event is emitted when an AMM pair is set or unset.
    event SetAmmPair(address pair, bool isPair);

    /// @dev This event is emitted when an address is excluded from fees.
    event SetExcludedFromFee(address addr, bool excluded);

    /// @dev This event is emitted when an address is excluded from max transaction amount.
    event SetExcludedFromMaxTx(address addr, bool excluded);

    /// @dev This event is emitted when an address is excluded from max wallet balance.
    event SetExcludedFromMaxWallet(address addr, bool excluded);

    /// @dev This event is emitted when limits are enabled or disabled.
    event SetLimitsEnabled(bool enabled);

    /// @dev This event is emitted when the feeWallet is changed.
    event UpdateFeeWallet(address oldFeeWallet, address newFeeWallet);

    /// @dev This event is emitted when the buy fee is changed.
    event UpdateBuyFee(uint256 oldBuyFee, uint256 newBuyFee);

    /// @dev This event is emitted when the sell fee is changed.
    event UpdateSellFee(uint256 oldSellFee, uint256 newSellFee);

    /// @dev This event is emitted when the max transaction amount is changed.
    event UpdateMaxTxAmount(uint256 newMaxTxAmount);

    /// @dev This event is emitted when the max wallet balance is changed.
    event UpdateMaxWalletBalance(uint256 newMaxWalletBalance);

    constructor(address _uniswapRouter, address _treasury) ERC20("Lucky8", "888") Ownable(msg.sender) {
        uniswapV2Router = IUniswapV2Router02(_uniswapRouter);

        canTransferBeforeTrading[owner()] = true;

        isExcludedFromFee[_treasury] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[_uniswapRouter] = true;

        isExcludedFromMaxTx[_treasury] = true;
        isExcludedFromMaxTx[address(this)] = true;
        isExcludedFromMaxTx[_uniswapRouter] = true;

        isExcludedFromMaxPerWallet[_treasury] = true;
        isExcludedFromMaxPerWallet[address(this)] = true;
        isExcludedFromMaxPerWallet[_uniswapRouter] = true;

        _mint(_treasury, 100_000_000 ether);
    }

    /// @dev This function is used to set the UniswapV2 pair.
    function setPair(address _pair) external onlyOwner {
        require(_pair != address(0), "Lucky8: pair is the zero address");

        // Set the pair.
        pair = _pair;
        // Set the pair as an AMM pair.
        isAmmPair[_pair] = true;
        // Exclude the pair from max transaction amount.
        isExcludedFromMaxTx[pair] = true;
        // Exclude the pair from max wallet balance.
        isExcludedFromMaxPerWallet[pair] = true;

        emit SetAmmPair(_pair, true);
    }

    /// @dev This function is used to enable or disable the blocklist.
    function setBlocklistEnabled(bool enabled) external onlyOwner {
        isBlocklistEnabled = enabled;
        emit SetBlocklistEnabled(enabled);
    }

    /// @dev Set can transfer before trading.
    function setCanTransferBeforeTrading(address addr, bool blocked) external onlyOwner {
        canTransferBeforeTrading[addr] = blocked;
        emit SetCanTransferBeforeTrading(addr, blocked);
    }

    /// @dev This function is used to add an address to the blocklist.
    function setBlockedAddress(address addr, bool blocked) external onlyOwner {
        isBlocked[addr] = blocked;
        emit SetBlockedAddress(addr, blocked);
    }

    /// @dev This function is used to set an AMM pair.
    function setAmmPair(address _pair, bool isPair) external onlyOwner {
        isAmmPair[_pair] = isPair;
        emit SetAmmPair(_pair, isPair);
    }

    /// @dev This function is used to set the fee wallet.
    function setFeeWallet(address _feeWallet) external onlyOwner {
        address oldFeeWallet = feeWallet;
        feeWallet = _feeWallet;
        emit UpdateFeeWallet(oldFeeWallet, feeWallet);
    }

    /// @dev This function is used to set an address as excluded from fees.
    function setExcludedFromFee(address addr, bool excluded) external onlyOwner {
        isExcludedFromFee[addr] = excluded;
        emit SetExcludedFromFee(addr, excluded);
    }

    /// @dev This function is used to set an address as excluded from max transaction amount.
    function setExcludedFromMaxTx(address addr, bool excluded) external onlyOwner {
        isExcludedFromMaxTx[addr] = excluded;
        emit SetExcludedFromMaxTx(addr, excluded);
    }

    /// @dev This function is used to set an address as excluded from max wallet balance.
    function setExcludedFromMaxPerWallet(address addr, bool excluded) external onlyOwner {
        isExcludedFromMaxPerWallet[addr] = excluded;
        emit SetExcludedFromMaxWallet(addr, excluded);
    }

    /// @dev This function is used to set the max transaction amount.
    function setMaxTxAmount(uint256 _maxTxAmount) external onlyOwner {
        maxTxAmount = _maxTxAmount;
        emit UpdateMaxTxAmount(_maxTxAmount);
    }

    /// @dev This function is used to set the max wallet balance.
    function setMaxWalletBalance(uint256 _maxWalletBalance) external onlyOwner {
        maxWalletBalance = _maxWalletBalance;
        emit UpdateMaxWalletBalance(_maxWalletBalance);
    }

    /// @dev This function is used to enable or disable limits.
    function setLimitsEnabled(bool enabled) external onlyOwner {
        limitsEnabled = enabled;
        emit SetLimitsEnabled(enabled);
    }

    /// @dev This function is used to set the buy fee.
    function setBuyFee(uint256 _buyFee) external onlyOwner {
        uint256 oldBuyFee = buyFee;
        buyFee = _buyFee;
        emit UpdateBuyFee(oldBuyFee, buyFee);
    }

    /// @dev This function is used to set the sell fee.
    function setSellFee(uint256 _sellFee) external onlyOwner {
        uint256 oldSellFee = sellFee;
        sellFee = _sellFee;
        emit UpdateSellFee(oldSellFee, sellFee);
    }

    /// @dev Burn the specified amount of tokens from the caller.
    function burn(address addr, uint256 amount) external onlyOwner {
        _burn(addr, amount);
    }

    /// @dev Update function..
    function _update(address _from, address _to, uint256 amount) internal override {
        // If the blocklist is enabled.
        if (isBlocklistEnabled) {
            // If the sender is blocked then revert.
            require(!isBlocked[_from], "ERC20: sender is blocked");

            // If the recipient is blocked then revert.
            require(!isBlocked[_to], "ERC20: recipient is blocked");
        }

        // Check that the uniswap pair is set.
        // If trading is not enabled and transfers are allowed only for the owner.
        if (pair == _ZERO_ADDR) {
            require(
                _from == _ZERO_ADDR || canTransferBeforeTrading[_from] || canTransferBeforeTrading[_to],
                "ERC20: trading is not enabled"
            );

            super._update(_from, _to, amount);
            return;
        }

        // Check that transfer amount is not greater than maxTxAmount
        // for non excluded addresses. Only when limits are enabled.
        if (limitsEnabled) {
            if (isAmmPair[_from] && !isExcludedFromMaxTx[_to]) {
                require(amount <= maxTxAmount, "ERC20: transfer amount exceeds the maxTxAmount");
            } else if (isAmmPair[_to] && !isExcludedFromMaxTx[_from]) {
                require(amount <= maxTxAmount, "ERC20: transfer amount exceeds the maxTxAmount");
            }

            // Check that recipient balance is not greater than maxWalletBalance
            if (!isExcludedFromMaxPerWallet[_to]) {
                require(
                    balanceOf(_to) + amount <= maxWalletBalance, "ERC20: wallet balance exceeds the maxWalletBalance"
                );
            }
        }

        // If amount is 0 then just execute the transfer and return.
        if (amount == 0) {
            super._update(_from, _to, amount);
            return;
        }

        // If sender or recipient is excluded from fee then just transfer and return.
        if (isExcludedFromFee[_from] || isExcludedFromFee[_to]) {
            super._update(_from, _to, amount);
            return;
        }

        // If sender or recipient is an AMM pair compute fee.
        uint256 fee;
        if (isAmmPair[_to] && sellFee > 0) {
            fee = (amount * sellFee) / 100;
        } else if (isAmmPair[_from] && buyFee > 0) {
            fee = (amount * buyFee) / 100;
        }

        // If fee is gt 0 then transfer fee to feeWallet and deduct the fee
        // from the original transfer amount.
        if (fee > 0 && feeWallet != _ZERO_ADDR) {
            super._update(_from, feeWallet, fee);
            amount -= fee;
        }

        super._update(_from, _to, amount);
    }
}
