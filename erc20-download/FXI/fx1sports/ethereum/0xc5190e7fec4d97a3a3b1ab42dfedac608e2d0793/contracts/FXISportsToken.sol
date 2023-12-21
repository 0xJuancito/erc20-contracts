//SPDX-License-Identifier: None

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IFXISportsToken.sol";

/// @title FXI Sports Token
/// @title https://fx1.io/
/// @title https://t.me/fx1_sports_portal
/// @author https://PROOFplatform.io
/// @author https://5thWeb.io

contract FXISportsToken is Ownable, IFXISportsToken {
    /// @notice Maps an address to its token balance
    mapping(address => uint256) private _balances;
    /// @notice Maps addresses to allowances granted by token holders
    mapping(address => mapping(address => uint256)) private _allowances;
    /// @notice Maps addresses to indicate whether they are excluded from transaction fees
    mapping(address => bool) public excludedFromFees;
    /// @notice Maps addresses to indicate whether they are excluded from maximum wallet balance limits
    mapping(address => bool) public excludedFromMaxWallet;
    /// @notice Maps addresses to indicate whether they are whitelisted
    mapping(address => bool) public whitelists;

    /// @notice Total supply of the FX1 Sports Token
    uint256 private _totalSupply = 300_000_000 * 10 ** _decimals;
    /// @notice Timestamp of the token contract launch
    uint256 public launchTime;
    /// @notice Period during which addresses can be added to the whitelist
    uint256 public whitelistPeriod;
    /// @notice Minimum amount of tokens required to trigger an automatic swap for liquidity
    uint256 public swapThreshold;
    /// @notice Maximum amount of tokens that a wallet can hold
    uint256 public maxWalletAmount;
    /// @notice Accumulated amount of tokens reserved for liquidity
    uint256 private accLiquidityAmount;
    /// @notice Accumulated amount of tokens reserved for marketing purposes
    uint256 private accMarketingAmount;

    /// @notice The cumulative fee rate applied to buy transactions
    uint256 public totalBuyFeeRate;
    /// @notice The cumulative fee rate applied to sale transactions
    uint256 public totalSellFeeRate;

    /// @notice Address for receiving marketing-related tax payments
    address public marketingTaxRecv;
    /// @notice Address of the generated token pair
    address public pair;
    /// @notice Address representing a dead wallet
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /// @notice Variable indicates whether a liquidity swap is in progress
    bool private inSwapLiquidity;

    /// @notice Name of the FX1 Sports Token
    string private _name = "FXI Sports";
    /// @notice Symbol of the FX1 Sports Token
    string private _symbol = "FXI";

    /// @notice Fixed-point multiplier used for calculations
    uint256 public immutable FIXED_POINT = 1000;
    /// @notice The maximum allowable fee rate
    uint16 public constant MAX_FEE = 100;
    /// @notice Number of decimal places for token values
    uint8 private constant _decimals = 18;

    /// @notice Router for interacting with the Uniswap decentralized exchange
    IUniswapV2Router02 public dexRouter;
    /// @notice Fee rates for buying transactions
    FeeRate public buyfeeRate;
    /// @notice Fee rates for selling transactions
    FeeRate public sellfeeRate;

    /// @notice Constructs the FX1SportsToken contract
    /// @param _param A struct containing various parameters required for the token's configuration
    constructor(
        FeeRate memory _buyfeeRate,
        FeeRate memory _sellfeeRate,
        Param memory _param
    ) checkFeeRates(_buyfeeRate) checkFeeRates(_sellfeeRate) {
        require(
            _param.marketingTaxRecv != address(0),
            "Invalid MarketingTaxRecv address"
        );
        require(_param.dexRouter != address(0), "Invalid dexRouter adddress");
        require(_param.whitelistPeriod > 0, "Invalid whitelistPeriod");
        address sender = msg.sender;
        marketingTaxRecv = _param.marketingTaxRecv;
        dexRouter = IUniswapV2Router02(_param.dexRouter);
        whitelistPeriod = _param.whitelistPeriod;
        buyfeeRate.liquidityFeeRate = _buyfeeRate.liquidityFeeRate;
        buyfeeRate.marketingFeeRate = _buyfeeRate.marketingFeeRate;
        totalBuyFeeRate =
            _buyfeeRate.liquidityFeeRate +
            _buyfeeRate.marketingFeeRate;

        sellfeeRate.liquidityFeeRate = _sellfeeRate.liquidityFeeRate;
        sellfeeRate.marketingFeeRate = _sellfeeRate.marketingFeeRate;
        totalSellFeeRate =
            _sellfeeRate.liquidityFeeRate +
            _sellfeeRate.marketingFeeRate;

        excludedFromFees[sender] = true;
        excludedFromMaxWallet[sender] = true;
        excludedFromMaxWallet[address(this)] = true;
        excludedFromMaxWallet[marketingTaxRecv] = true;
        whitelists[sender] = true;
        whitelists[address(this)] = true;

        _balances[sender] += _totalSupply;
        emit Transfer(address(0), sender, _totalSupply);
        swapThreshold = _totalSupply / 10000; // 0.01%
    }

    receive() external payable {}

    /**
     * @notice A modifier to check and enforce the maximum fee rates for marketing and liquidity
     * @param _fees The structure containing marketing and liquidity fee rates
     */
    modifier checkFeeRates(FeeRate memory _fees) {
        require(
            _fees.marketingFeeRate + _fees.liquidityFeeRate <= MAX_FEE,
            "Max Rate exceeded, please lower value"
        );
        _;
    }

    /// ================================ Functions for ERC20 token ================================ ///

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) external view override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function approve(
        address _spender,
        uint256 _amount
    ) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        uint256 currentAllowance = _allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "Transfer > allowance");
        _approve(_sender, msg.sender, currentAllowance - _amount);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    /// ================================ External functions ================================ ///

    /**
     * @notice Updates the address of the Uniswap router
     * @param _newRouter The new address of the Uniswap router
     */
    function updateDexRouter(address _newRouter) external onlyOwner {
        require(Address.isContract(_newRouter), "Address is not a contract");
        dexRouter = IUniswapV2Router02(_newRouter);
    }

    /**
     * @notice External function update the Uniswap pair address and adjust exemption settings
     * @param _pair The new Uniswap pair address
     */
    function updatePair(address _pair) external onlyOwner {
        require(_pair != address(0), "Invalid pair address");
        if (pair != address(0)) {
            excludedFromMaxWallet[pair] = false;
            whitelists[pair] = false;
        }
        pair = _pair;
        excludedFromMaxWallet[_pair] = true;
        whitelists[_pair] = true;
    }

    /**
     * @notice External function update the whitelist period
     * @param _newWhiteListPeriod The new duration of the whitelist period in seconds
     */
    function setWhiteListPeriod(
        uint256 _newWhiteListPeriod
    ) external onlyOwner {
        require(_newWhiteListPeriod > 0, "Invalid whitelistPeriod");
        whitelistPeriod = _newWhiteListPeriod;
    }

    /**
     * @notice External function for allows the contract owner to send FX1SportsToken amounts of tokens to multiple recipients
     * @param _recipients An array of recipient addresses to send tokens to
     * @param _amounts An array of corresponding token amounts to be sent to each recipient
     */
    function multiSender(
        address[] memory _recipients,
        uint256[] memory _amounts
    ) external onlyOwner {
        require(_recipients.length == _amounts.length, "Invalid arrays length");

        uint256 totalAmountToSend = 0;
        for (uint256 i = 0; i < _recipients.length; ) {
            require(_recipients[i] != address(0), "Invalid recipient address");
            totalAmountToSend += _amounts[i];

            unchecked {
                i++;
            }
        }

        require(
            _balances[msg.sender] >= totalAmountToSend,
            "Not enough balance to send"
        );
        for (uint256 i = 0; i < _recipients.length; ) {
            _transfer(msg.sender, _recipients[i], _amounts[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice External function allows the contract owner to set the launch time of the token
     */
    function setLaunchBegin() external override onlyOwner {
        require(launchTime == 0, "Already launched");
        launchTime = block.timestamp;
    }

    /**
     * @notice External function allows the contract owner to add or remove multiple addresses from the whitelists
     * @param _accounts An array of addresses to be added or removed from the whitelists
     * @param _add A boolean indicating whether to add or remove the addresses from the whitelists
     */
    function updateWhitelists(
        address[] memory _accounts,
        bool _add
    ) external override onlyOwner {
        uint256 length = _accounts.length;
        require(length > 0, "Invalid accounts length");

        for (uint256 i = 0; i < length; ) {
            whitelists[_accounts[i]] = _add;

            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice External function allows the contract owner to exclude or include multiple addresses from the list of addresses exempted from maximum wallet balance limits
     * @param _accounts An array of addresses to be excluded or included in the list
     * @param _add A boolean indicating whether to exclude or include the addresses in the list
     */
    function excludeWalletsFromMaxWallets(
        address[] memory _accounts,
        bool _add
    ) external override onlyOwner {
        uint256 length = _accounts.length;
        require(length > 0, "Invalid length array");
        for (uint256 i = 0; i < length; ) {
            excludedFromMaxWallet[_accounts[i]] = _add;

            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice External function allows the contract owner to exclude or include multiple addresses from the list of addresses exempted from transaction fees
     * @param _accounts An array of addresses to be excluded or included in the list
     * @param _add A boolean indicating whether to exclude or include the addresses in the list
     */
    function excludeWalletsFromFees(
        address[] memory _accounts,
        bool _add
    ) external override onlyOwner {
        uint256 length = _accounts.length;
        require(length > 0, "Invalid length array");
        for (uint256 i = 0; i < length; ) {
            excludedFromFees[_accounts[i]] = _add;

            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice External function allows the contract owner to set a new maximum wallet balance limit
     * @param newLimit The new maximum transfer amount limit to be set
     */
    function setMaxWalletAmount(uint256 newLimit) external override onlyOwner {
        require(newLimit >= (_totalSupply * 10) / 1000, "Min 1% limit");
        maxWalletAmount = newLimit;
    }

    /**
     * @notice External function allows the contract owner to set a new address for the marketing tax wallet
     * @param _marketingTaxWallet The new address to be set as the marketing tax wallet
     */
    function setMarketingTaxWallet(
        address _marketingTaxWallet
    ) external override onlyOwner {
        require(
            _marketingTaxWallet != address(0),
            "Invalid marketingTaxWallet address"
        );
        marketingTaxRecv = _marketingTaxWallet;
    }

    /**
     * @notice This function allows the contract owner to update the fee rates for buy operations
     * @param _marketingBuyFeeRate New marketing fee rate for buy operations
     * @param _liquidityBuyFeeRate New liquidity fee rate for buy operations
     */
    function updateBuyFeeRate(
        uint16 _marketingBuyFeeRate,
        uint16 _liquidityBuyFeeRate
    ) external override onlyOwner {
        require(
            _marketingBuyFeeRate + _liquidityBuyFeeRate <= MAX_FEE,
            "Max Rate exceeded, please lower value"
        );
        buyfeeRate.marketingFeeRate = _marketingBuyFeeRate;
        buyfeeRate.liquidityFeeRate = _liquidityBuyFeeRate;
        totalBuyFeeRate = _marketingBuyFeeRate + _liquidityBuyFeeRate;
    }

    /**
     * @notice This function allows the contract owner to update the fee rates for sell operations
     * @param _marketingSellFeeRate New marketing fee rate for sell operations
     * @param _liquiditySellFeeRate New liquidity fee rate for sell operations
     */
    function updateSellFeeRate(
        uint16 _marketingSellFeeRate,
        uint16 _liquiditySellFeeRate
    ) external override onlyOwner {
        require(
            _marketingSellFeeRate + _liquiditySellFeeRate <= MAX_FEE,
            "Max Rate exceeded, please lower value"
        );
        sellfeeRate.marketingFeeRate = _marketingSellFeeRate;
        sellfeeRate.liquidityFeeRate = _liquiditySellFeeRate;
        totalSellFeeRate = _marketingSellFeeRate + _liquiditySellFeeRate;
    }

    /**
     * @notice External function allows the contract owner to set a new swap threshold value
     * @param _swapThreshold The new swap threshold value to be set
     */
    function setSwapThreshold(
        uint256 _swapThreshold
    ) external override onlyOwner {
        require(_swapThreshold > 0, "Invalid swapThreshold");
        swapThreshold = _swapThreshold;
    }

    /// ================================ Internal functions ================================ ///

    /**
     * @notice Internal function to perform token transfer between two addresses, subject to various checks and conditions
     * @param _sender The address from which tokens are being transferred
     * @param _recipient The address to which tokens are being transferred
     * @param _amount The amount of tokens being transferred
     */
    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        require(_sender != address(0), "Transfer from zero address");
        require(_recipient != address(0), "Transfer to zero address");
        require(_amount > 0, "Zero amount");
        require(_balances[_sender] >= _amount, "Not enough amount to transfer");
        require(_sender == owner() || launchTime != 0, "Not launched yet");
        if (block.timestamp < launchTime + whitelistPeriod) {
            require(whitelists[_recipient], "only whitelist");
        }
        if (maxWalletAmount > 0) {
            require(
                excludedFromMaxWallet[_recipient] ||
                    _balances[_recipient] + _amount <= maxWalletAmount,
                "Exceeds to maxWalletAmount"
            );
        }
        if (
            inSwapLiquidity ||
            excludedFromFees[_recipient] ||
            excludedFromFees[_sender]
        ) {
            _basicTransfer(_sender, _recipient, _amount);
            emit Transfer(_sender, _recipient, _amount);
            return;
        }
        if (pair != address(0)) {
            if (_sender == pair) {
                // buy
                _taxonBuyTransfer(_sender, _recipient, _amount);
            } else {
                _swapBack();

                if (_recipient == pair) {
                    // sell
                    _taxonSellTransfer(_sender, _recipient, _amount);
                } else {
                    _basicTransfer(_sender, _recipient, _amount);
                }
            }
        }

        emit Transfer(_sender, _recipient, _amount);
    }

    /**
     * @notice Internal function to swap excess tokens in the contract back to ETH and manage liquidity and fees
     */
    function _swapBack() internal {
        uint256 accTotalAmount = accLiquidityAmount + accMarketingAmount;
        if (accTotalAmount <= swapThreshold) {
            return;
        }
        inSwapLiquidity = true;
        uint256 swapAmountForLiquidity = accLiquidityAmount / 2;
        uint256 swapAmount = accTotalAmount - swapAmountForLiquidity;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();
        _approve(address(this), address(dexRouter), swapAmount);
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0,
            path,
            address(this),
            block.timestamp + 30 minutes
        );
        uint256 swappedETHAmount = address(this).balance;
        require(swappedETHAmount > 0, "Too small token for swapBack");
        uint256 ethForLiquidity = (swappedETHAmount * swapAmountForLiquidity) /
            swapAmount;

        if (ethForLiquidity > 0) {
            uint256 amountForLiquidity = accLiquidityAmount -
                swapAmountForLiquidity;
            _approve(address(this), address(dexRouter), amountForLiquidity);
            dexRouter.addLiquidityETH{value: ethForLiquidity}(
                address(this),
                amountForLiquidity,
                0,
                0,
                0x000000000000000000000000000000000000dEaD,
                block.timestamp + 30 minutes
            );
            swappedETHAmount -= ethForLiquidity;
        }

        _transferETH(marketingTaxRecv, swappedETHAmount);

        accLiquidityAmount = 0;
        accMarketingAmount = 0;
        inSwapLiquidity = false;
    }

    /**
     * @notice Internal function to handle transfers when tokens are being sold
     * @param _sender The address of the sender (seller)
     * @param _recipient The address of the recipient (buyer)
     * @param _amount The amount of tokens being transferred
     */
    function _taxonSellTransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        (
            uint256 marketingFeeRate,
            uint256 liquidityFeeRate
        ) = _getSellFeeRate();

        uint256 marketingFeeAmount = (_amount * marketingFeeRate) / FIXED_POINT;
        uint256 liquidityFeeAmount = (_amount * liquidityFeeRate) / FIXED_POINT;
        uint256 recvAmount = _amount -
            (marketingFeeAmount + liquidityFeeAmount);

        _balances[_sender] -= _amount;
        _balances[_recipient] += recvAmount;
        _balances[address(this)] += (marketingFeeAmount + liquidityFeeAmount);
        accLiquidityAmount += liquidityFeeAmount;
        accMarketingAmount += marketingFeeAmount;
    }

    /**
     * @notice Internal function to handle transfers when tokens are being bought
     * @param _sender The address of the sender (buyer)
     * @param _recipient The address of the recipient (seller)
     * @param _amount The amount of tokens being transferred
     */
    function _taxonBuyTransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        (uint256 marketingFeeRate, uint256 liquidityFeeRate) = _getBuyFeeRate();

        uint256 marketingFeeAmount = (_amount * marketingFeeRate) / FIXED_POINT;
        uint256 liquidityFeeAmount = (_amount * liquidityFeeRate) / FIXED_POINT;
        uint256 recvAmount = _amount -
            (marketingFeeAmount + liquidityFeeAmount);

        _balances[_sender] -= _amount;
        _balances[_recipient] += recvAmount;
        _balances[address(this)] += (marketingFeeAmount + liquidityFeeAmount);
        accLiquidityAmount += liquidityFeeAmount;
        accMarketingAmount += marketingFeeAmount;
    }

    /**
     * @notice Internal function to perform a basic transfer of tokens between two addresses
     * @param _sender The address of the sender
     * @param _recipient The address of the recipient
     * @param _amount The amount of tokens to transfer
     */
    function _basicTransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        _balances[_sender] -= _amount;
        _balances[_recipient] += _amount;
    }

    /**
     * @notice Internal function to get the fee rates for selling tokens based on the current time period after launch
     */
    function _getSellFeeRate()
        internal
        view
        returns (uint256 _marketingFeeRate, uint256 _liquidityFeeRate)
    {
        return (sellfeeRate.marketingFeeRate, sellfeeRate.liquidityFeeRate);
    }

    /**
     * @notice Internal function to get the fee rates for buying tokens based on the current time period after launch
     */
    function _getBuyFeeRate()
        internal
        view
        returns (uint256 _marketingFeeRate, uint256 _liquidityFeeRate)
    {
        return (buyfeeRate.marketingFeeRate, buyfeeRate.liquidityFeeRate);
    }

    /**
     * @notice Internal function to transfer ETH to a specified recipient
     * @param _recipient The address of the recipient to which ETH should be transferred
     * @param _amount The amount of ETH to transfer
     */
    function _transferETH(address _recipient, uint256 _amount) internal {
        if (_amount == 0) return;
        (bool sent, ) = _recipient.call{value: _amount}("");
        require(sent, "Sending ETH failed");
    }

    /// ================================ Private functions ================================ ///

    /**
     * @notice Private function to set the allowance amount that `_spender` can spend on behalf of `_owner`
     * @param _owner The address that approves spending
     * @param _spender The address that is allowed to spend
     * @param _amount The amount of tokens that `_spender` is allowed to spend
     */
    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) private {
        require(_owner != address(0), "Approve from zero");
        require(_spender != address(0), "Approve to zero");
        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }
}
