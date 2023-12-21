// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

/// @title This is official MAGNET Token contract ERC20 used in the Yield Magnet platform
/// @author Yield Magnet Team

struct StakingContract {
    address contractAddress;
    uint8 percentage;
}

contract YieldMagnetToken is ERC20, Ownable {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                            TAX VARIABLES
    //////////////////////////////////////////////////////////////*/
    struct WalletState {
        bool isMarketPair;
        bool isExemptFromTax;
    }
    // Saves gas!
    mapping(address => WalletState) public walletStates;

    // Set to 10/10 when trading is open. SetTaxes can only set it
    // up to 10/10.
    uint8 public buyTax = 0;
    uint8 public sellTax = 0;

    // Must always add up to 100.
    uint8 public platformPercentage = 60;
    uint8 public stakerPercentage = 20;
    uint8 public lpPercentage = 20;

    // When set is true, tax will no longer be change-able.
    bool private _isTaxRenounced = false;
    bool private _isTaxEnabled = true;

    /*//////////////////////////////////////////////////////////////
                            CONTRACT SWAP
    //////////////////////////////////////////////////////////////*/
    
    // Once switched on, can never be switched off.
    bool public isTradingOpen = false;

    bool private _inSwap = false;
    uint256 public taxDistributionThreshold = 5_000_000 * 10 ** 18;

    /*//////////////////////////////////////////////////////////////
                            UNISWAP
    //////////////////////////////////////////////////////////////*/

    IUniswapV2Router02 public uniswapV2Router;

    /*//////////////////////////////////////////////////////////////
                            TAX RECIPIENTS
    //////////////////////////////////////////////////////////////*/
    
    // Platform cut will be sent to this address.
    // Defaults to contract creator.
    address public taxAddress;

    // LP tokens will be sent to this address.
    // Defaults to contract creator.
    address public lpAddress;

    // Staking cut will be distributed to these contracts.
    // The percentages must always add up to 100.
    StakingContract[] private _stakingContracts;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event TaxDistributed(
        uint256 platformCut,
        uint256 stakersCut,
        uint256 liquidityCut
    );
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount);
    event PlatformTaxDistributed(uint256 amount);

    event UniswapRouterUpdated(address newRouter);
    event ExcludedFromFeesUpdated(address wallet, bool isExcluded);
    event MarketPairUpdated(address pair, bool isMarketPair);

    event StakingContractsUpdated(
        address[] stakingContracts,
        uint8[] percentages
    );
    event TaxAddressUpdated(address newTaxAddress);
    event LpAddressUpdated(address newLpAddress);

    event TradingOpen();
    event TaxRenounced();
    event TaxStatusUpdated(bool isTaxEnabled);
    event TaxesUpdated(uint8 buyTax, uint8 sellTax);

    event DistributionThresholdUpdated(uint256 newThreshold);
    event DistributionPercentagesUpdated(
        uint8 platformPercentage,
        uint8 stakerPercentage,
        uint8 lpPercentage
    );

    /*//////////////////////////////////////////////////////////////
                            MAIN LOGIC
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("Yield Magnet", "MAGNET") Ownable(msg.sender) {
        super._update(address(0), msg.sender, (1_000_000_000 * 10 ** 18));

        address uniswapV2Router02Address = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; 
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            uniswapV2Router02Address
        );

        // Create the pair and mark it as a market pair to enable taxes.
        address uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        _approve(address(this), uniswapV2Router02Address, type(uint256).max);
        setMarketPair(uniswapV2Pair, true);

        taxAddress = msg.sender;
        lpAddress = msg.sender;

        // Exclude owner, this contract and Uniswap router from fees.
        walletStates[msg.sender] = WalletState({
            isMarketPair: false,
            isExemptFromTax: true
        });
        emit ExcludedFromFeesUpdated(msg.sender, true);
        walletStates[address(this)] = WalletState({
            isMarketPair: false,
            isExemptFromTax: true
        });
        emit ExcludedFromFeesUpdated(address(this), true);
        walletStates[uniswapV2Router02Address] = WalletState({
            isMarketPair: false,
            isExemptFromTax: true
        });
        emit ExcludedFromFeesUpdated(uniswapV2Router02Address, true);
    }

    receive() external payable {}

    /// @notice Returns if an address is excluded from tax.
    function isTaxExempt(address account_) external view returns (bool) {
        return walletStates[account_].isExemptFromTax;
    }

    /// @notice Returns if the tax is enabled or not. Tax only exists on market pairs.
    function isTaxEnabled() external view returns (bool) {
        return _isTaxEnabled;
    }

    /// @notice Returns if tax is renounced, meaning that the taxes cannot be changed.
    function isTaxRenounced() external view returns (bool) {
        return _isTaxRenounced;
    }

    /// @notice _update function overrides the _update function from the perent contract and contains logic for tax and tax distribution
    /// @dev this override function will be called from the top level transfer and transferFrom function whenever user initates transfer or buy and sell happens
    /// @dev this function breaks _mint. Use super._update instead.
    /// @param from address from the amount will be transfered
    /// @param to address to where the amount will be transfered
    /// @param amount number of tokens to transfer
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Parent ERC20 already checks that from/to are not zero address.

        uint256 fromBalance = balanceOf(from);
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        WalletState memory fromState = walletStates[from];
        WalletState memory toState = walletStates[to];

        bool isTaxExempt_ = (fromState.isExemptFromTax || toState.isExemptFromTax);

        uint256 taxAmount;

        if(fromState.isMarketPair || toState.isMarketPair) {
            require(isTradingOpen || msg.sender == owner() || tx.origin == owner(), "Trading not open yet");
        }

        if (fromState.isMarketPair && isTaxExempt_ == false && _isTaxEnabled) {
            taxAmount = (amount * buyTax) / 100;
        } else if (
            toState.isMarketPair && isTaxExempt_ == false && _isTaxEnabled
        ) {
            taxAmount = (amount * sellTax) / 100;
        } else {
            taxAmount = 0;
        }

        if (
            balanceOf(address(this)) > taxDistributionThreshold &&
            _inSwap == false &&
            fromState.isMarketPair == false && // Don't swap on buys.
            toState.isMarketPair == true // Only swap on sells.
        ) {
            try this.distributeTax() {} catch(bytes memory) {}
        }

        if (taxAmount != 0 && _inSwap == false) {
            super._update(from, to, amount - taxAmount);
            super._update(from, address(this), taxAmount);
        } else {
            super._update(from, to, amount);
        }
    }

    modifier lockTheSwap {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    /// @notice Distributes the collected tax to the platform, stakers and liquidity.
    function distributeTax() external lockTheSwap {
        require(msg.sender == address(this) || msg.sender == owner(), "owner/contract only");

        uint256 contractBalance = balanceOf(address(this));
        uint256 platformCut = (contractBalance * platformPercentage) / 100;
        uint256 stakerCut = (contractBalance * stakerPercentage) / 100;
        uint256 lpCut = (contractBalance * lpPercentage) / 100;

        require(
            (platformCut + stakerCut + lpCut) <= balanceOf(address(this)),
            "YieldMagnet: Can't distribute the funds"
        );
        _distributeStakersCut(stakerCut);
        _handleLiquidityAndPlatformCut(platformCut, lpCut);
        emit TaxDistributed(platformCut, stakerCut, lpCut);
    }

    /// @notice Distributes the stakers cut to the staking contracts.
    /// @dev All staking contract's percentages must add up to exactly 100.
    function _distributeStakersCut(uint256 stakersCut_) private {
        for (uint256 i = 0; i < _stakingContracts.length; i++) {
            StakingContract memory sc = _stakingContracts[i];

            uint256 stakerContractCut = (sc.percentage * stakersCut_) / 100;

            super._update(address(this), sc.contractAddress, stakerContractCut);
        }
    }

    /// @notice Distributes liquidity and platform cut. Swaps both to ETH, adds liquidity, and sends the remaining ETH to the tax address.
    /// @param platformCut amount of tokens to swap and send as ETH to taxAddress.
    /// @param lpCut half tokens are swapped, half added to liquidity.
    function _handleLiquidityAndPlatformCut(uint256 platformCut, uint256 lpCut) private {
        uint256 initBal = address(this).balance;
        _swapTokensForEth(lpCut/2 - 1 + platformCut);
        if(lpCut > 0) {
            uint256 receiveBalance = address(this).balance - initBal;
            uint256 ethForLiq = receiveBalance * lpCut / (lpCut + platformCut);
            _addLiquidity(lpCut/2, ethForLiq);
            emit LiquidityAdded(lpCut/2, ethForLiq);
        }

        // Send any remaining ETH to the tax address. This will equal to the platform cut.
        uint256 amount = address(this).balance;
        (bool success,) =  taxAddress.call{value: amount}("");
        require(success, "YieldMagnet: Failed to send ETH to tax address");
        emit PlatformTaxDistributed(amount);
    }

    /// @notice Swaps the token amount to ETH using the Uniswap V2 router.
    function _swapTokensForEth(uint256 tokenAmount_) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        require(
            tokenAmount_ > 0,
            "YieldMagnet: Token amount less then 0 for token swap"
        );
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount_,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /// @notice Adds liquidity to the Uniswap V2 pair. LP tokens are sent to the lpAddress.
    /// @dev Approvals happen when setting the router address.
    function _addLiquidity(uint256 tokenAmount_, uint256 ethAmount_) private {
        uniswapV2Router.addLiquidityETH{value: ethAmount_}(
            address(this),
            tokenAmount_,
            0,
            0,
            lpAddress,
            block.timestamp
        );
    }

    /*//////////////////////////////////////////////////////////////
                            STAKING CONTRACTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the Staking contract address and their percentages.
    function getStakingContracts()
        public
        view
        returns (StakingContract[] memory)
    {
        return _stakingContracts;
    }

    /// @notice Sets the staking contracts and their respective percentages. Percentages must add up to 100.
    /// @dev Deletes any previous _stakingContracts.
    /// @param stakingContracts_ The array of Staking contract addresses
    /// @param percentages_ The array of Staking contract distribution perccentages
    function updateStakingContracts(
        address[] memory stakingContracts_,
        uint8[] memory percentages_
    ) external onlyOwner {
        require(
            stakingContracts_.length == percentages_.length,
            "YieldMagnet: No of address and No of Percentages doesn't match!"
        );
        require(stakingContracts_.length <= 10, "YieldMagnet: Max 10 staking contracts allowed!");

        // Clear the existing staking contracts.
        delete _stakingContracts;

        uint8 totalPercent = 0;
        for (uint256 i = 0; i < stakingContracts_.length; i++) {
            require(
                percentages_[i] >= 0 && percentages_[i] <= 100,
                "YieldMagnet: percentage should be between  0 to 100!"
            );
            require(
                stakingContracts_[i] != address(0),
                "YieldMagnet: Staking contract may not be 0x0"
            );

            _stakingContracts.push(
                StakingContract(stakingContracts_[i], percentages_[i])
            );
            totalPercent += percentages_[i];
        }
        require(
            totalPercent == 100,
            "YieldMagnet: Total Percentage should be 100."
        );

        emit StakingContractsUpdated(stakingContracts_, percentages_);
    }

     /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Opens the trading, enabling taxes. Can only be called once.
    function openTrading() external onlyOwner {
        require(isTradingOpen == false, "Trading already open");

        isTradingOpen = true;
        buyTax = 10;
        sellTax = 10;

        emit TradingOpen();
    }

    /// @notice Renounces the tax, meaning that it can never be changed again.
    function renounceTax() public onlyOwner {
        _isTaxRenounced = true;
        emit TaxRenounced();
    }

    /// @notice Sets the Uniswap router address to use for swapping taxes and adding liquidity.
    function updateUniswapRouter(address newRouter) external onlyOwner {
        address oldAddress = address(uniswapV2Router);
        require(oldAddress != newRouter, "Address already set");

        _approve(address(this), oldAddress, 0);
        _approve(address(this), newRouter, type(uint256).max);

        uniswapV2Router = IUniswapV2Router02(newRouter);

        emit UniswapRouterUpdated(newRouter);
    }

    /// @notice Sets an address's tax exempt status.
    function setTaxExempt(address account, bool isExempt) external onlyOwner {
        require(account != address(this), "Can't change contract");
        WalletState memory state = walletStates[account];
        state.isExemptFromTax = isExempt;
        walletStates[account] = state;
        emit ExcludedFromFeesUpdated(account, isExempt);
    }

    /// @notice Toggles if tax is enabled or not.
    function setTaxEnabled(bool taxStatus_) external onlyOwner {
        _isTaxEnabled = taxStatus_;

        emit TaxStatusUpdated(taxStatus_);
    }

    /// @notice Set the receiver of platform taxes.
    function setTaxAddress(address newTaxAddress_) external onlyOwner {
        taxAddress = newTaxAddress_;
        emit TaxAddressUpdated(newTaxAddress_);
    }

    /// @notice Sets the address that will receive LP tokens from liquidity adds.
    function setLpAddress(address newLpAddress_) external onlyOwner {
        lpAddress = newLpAddress_;
        emit LpAddressUpdated(newLpAddress_);
    }

    /// @notice Sets the tax percentages for buy and sell. Can only be called before tax is renounced.
    /// @dev it sets buyTax to the newBuyTax_ and sellTax to the newSellTax_
    /// @param newBuyTax_ new buy tax. Cannot exceed 10.
    /// @param newSellTax_ new sell tax. Cannot exceed 10.
    function setTaxAmount(
        uint8 newBuyTax_,
        uint8 newSellTax_
    ) external onlyOwner {
        require(_isTaxRenounced == false, "YieldMagnet: Tax is renounced!");
        require(
            newBuyTax_ <= 10 && newSellTax_ <= 10,
            "YieldMagnet: Tax Should be less then 10!"
        );
        buyTax = newBuyTax_;
        sellTax = newSellTax_;
        emit TaxesUpdated(newBuyTax_, newSellTax_);
    }

    /// @notice setMarketPair updates the market pair status. Taxes apply from/to market pairs.
    function setMarketPair(address account, bool value) public onlyOwner {
        require(account != address(this), "cant change contract");
        WalletState memory state = walletStates[account];
        state.isMarketPair = value;
        walletStates[account] = state;
        emit MarketPairUpdated(account, value);
    }

    /// @notice Updates the tax distribution percentage between platform, stakers and liquidity.
    /// @dev sum of all three percentage must be == 100 for proper distribution.
    /// @param platformPercentage_ percentage for the platform
    /// @param stakerPercentage_ percentage for the stakers
    /// @param lpPercentage_ percentage for the liquidity
    function setDistributionPercentage(
        uint8 platformPercentage_,
        uint8 stakerPercentage_,
        uint8 lpPercentage_
    ) external onlyOwner {
        require(
            (platformPercentage_ + stakerPercentage_ + lpPercentage_) == 100,
            "YieldMagnet: Percentage should sum to 100!"
        );
        platformPercentage = platformPercentage_;
        stakerPercentage = stakerPercentage_;
        lpPercentage = lpPercentage_;
        emit DistributionPercentagesUpdated(
            platformPercentage_,
            stakerPercentage_,
            lpPercentage_
        );
    }

    /// @notice Changes the balance threshold for when tax is distributed.
    /// @dev it sets taxDistributionThreshold to newTaxDistributionThreshold_ also multiply it with the decimals
    /// @param newTaxDistributionThreshold_ number of whole tokens for the threshold. Decimals are added automatically.
    function changeTaxDistributionThreshold(
        uint256 newTaxDistributionThreshold_
    ) external onlyOwner {
        require(
            newTaxDistributionThreshold_ > 0,
            "YieldMagnet: Threshold can't be 0"
        );
        taxDistributionThreshold = newTaxDistributionThreshold_ * 10 ** 18;
        emit DistributionThresholdUpdated(newTaxDistributionThreshold_);
    }

    /// @notice Rescue any tokens that are stuck in the contract.
    function rescueStuckTokens(
        address tokenAddress_,
        uint256 amount_
    ) external onlyOwner {
        require(amount_ > 0, "YieldMagnet: amount can't be 0");
        IERC20 token = IERC20(tokenAddress_);
        token.safeTransfer(msg.sender, amount_);
    }

    /// @notice Rescues any ETH that are stuck in the contract.
    function rescueStuckETH(uint256 amount_) external onlyOwner {
        require(amount_ > 0, "YieldMagnet: amount can't be 0");
        (bool success,) = msg.sender.call{value: amount_}("");
        require(success, "failed to send eth");
    }
}