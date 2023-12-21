// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libs/ERC20.sol";
import "./libs/IERC20.sol";
import "./libs/SafeERC20.sol";
import "./libs/IWETH.sol";

import "./libs/AddLiquidityHelper.sol";
import "./libs/RHCPToolBox.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// ArcadiumToken.
contract ArcadiumToken is ERC20("ARCADIUM", "ARCADIUM")  {
    using SafeERC20 for IERC20;

    // Transfer tax rate in basis points. (default 6.66%)
    uint16 public transferTaxRate = 666;
    // Extra transfer tax rate in basis points. (default 2.00%)
    uint16 public extraTransferTaxRate = 200;
    // Burn rate % of transfer tax. (default 54.95% x 6.66% = 3.660336% of total amount).
    uint32 public constant burnRate = 549549549;
    // Max transfer tax rate: 10.01%.
    uint16 public constant MAXIMUM_TRANSFER_TAX_RATE = 1001;
    // Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public constant usdcCurrencyAddress = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    uint256 public constant usdcSwapThreshold = 20 * (10 ** 6);

    // Automatic swap and liquify enabled
    bool public swapAndLiquifyEnabled = true;
    // Min amount to liquify. (default 40 ARCADIUMs)
    uint256 public constant minArcadiumAmountToLiquify = 40 * (10 ** 18);
    // Min amount to liquify. (default 100 MATIC)
    uint256 public constant minMaticAmountToLiquify = 100 *  (10 ** 18);

    IUniswapV2Router02 public arcadiumSwapRouter;
    // The trading pair
    address public arcadiumSwapPair;
    // In swap and liquify
    bool private _inSwapAndLiquify;

    AddLiquidityHelper public immutable addLiquidityHelper;
    RHCPToolBox public immutable arcadiumToolBox;
    IERC20 public immutable usdcRewardCurrency;
    address public immutable myFriends;

    bool public ownershipIsTransferred = false;

    mapping(address => bool) public excludeFromMap;
    mapping(address => bool) public excludeToMap;

    mapping(address => bool) public extraFromMap;
    mapping(address => bool) public extraToMap;

    event SetSwapAndLiquifyEnabled(bool swapAndLiquifyEnabled);
    event TransferFeeChanged(uint256 txnFee, uint256 extraTxnFee);
    event UpdateFeeMaps(address _contract, bool fromExcluded, bool toExcluded, bool fromHasExtra, bool toHasExtra);
    event SetArcadiumRouter(address arcadiumSwapRouter, address arcadiumSwapPair);
    event SetOperator(address operator);

    // The operator can only update the transfer tax rate
    address private _operator;

    modifier onlyOperator() {
        require(_operator == msg.sender, "!operator");
        _;
    }

    modifier lockTheSwap {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    modifier transferTaxFree {
        uint16 _transferTaxRate = transferTaxRate;
        uint16 _extraTransferTaxRate = extraTransferTaxRate;
        transferTaxRate = 0;
        extraTransferTaxRate = 0;
        _;
        transferTaxRate = _transferTaxRate;
        extraTransferTaxRate = _extraTransferTaxRate;
    }

    /**
     * @notice Constructs the ArcadiumToken contract.
     */
    constructor(address _myFriends, AddLiquidityHelper _addLiquidityHelper, RHCPToolBox _arcadiumToolBox) public {
        addLiquidityHelper = _addLiquidityHelper;
        arcadiumToolBox = _arcadiumToolBox;
        myFriends = _myFriends;
        usdcRewardCurrency = IERC20(usdcCurrencyAddress);
        _operator = _msgSender();

        // pre-mint
        _mint(address(0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31), uint256(325000 * (10 ** 18)));
    }

    function transferOwnership(address newOwner) public override onlyOwner  {
        require(!ownershipIsTransferred, "!unset");
        super.transferOwnership(newOwner);
        ownershipIsTransferred = true;
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        require(ownershipIsTransferred, "too early!");
        _mint(_to, _amount);
    }

    /// @dev overrides transfer function to meet tokenomics of ARCADIUM
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        bool toFromAddLiquidityHelper = (sender == address(addLiquidityHelper) || recipient == address(addLiquidityHelper));
        // swap and liquify
        if (
            swapAndLiquifyEnabled == true
            && _inSwapAndLiquify == false
            && address(arcadiumSwapRouter) != address(0)
            && !toFromAddLiquidityHelper
            && sender != arcadiumSwapPair
            && sender != owner()
        ) {
            swapAndLiquify();
        }

        if (toFromAddLiquidityHelper ||
            recipient == BURN_ADDRESS || (transferTaxRate == 0 && extraTransferTaxRate == 0) ||
            excludeFromMap[sender] || excludeToMap[recipient]) {
            super._transfer(sender, recipient, amount);
        } else {
            // default tax is 6.66% of every transfer, but extra 2% for dumping tax
            uint256 taxAmount = (amount * (transferTaxRate +
                ((extraFromMap[sender] || extraToMap[recipient]) ? extraTransferTaxRate : 0))) / 10000;

            uint256 burnAmount = (taxAmount * burnRate) / 1000000000;
            uint256 liquidityAmount = taxAmount - burnAmount;

            // default 93.34% of transfer sent to recipient
            uint256 sendAmount = amount - taxAmount;

            require(amount == sendAmount + taxAmount &&
                        taxAmount == burnAmount + liquidityAmount, "sum error");

            super._transfer(sender, BURN_ADDRESS, burnAmount);
            super._transfer(sender, address(this), liquidityAmount);
            super._transfer(sender, recipient, sendAmount);
            amount = sendAmount;
        }
    }

    /// @dev Swap and liquify
    function swapAndLiquify() private lockTheSwap transferTaxFree {
        uint256 contractTokenBalance = ERC20(address(this)).balanceOf(address(this));

        uint256 WETHbalance = IERC20(arcadiumSwapRouter.WETH()).balanceOf(address(this));

        IWETH(arcadiumSwapRouter.WETH()).withdraw(WETHbalance);

        if (address(this).balance >= minMaticAmountToLiquify || contractTokenBalance >= minArcadiumAmountToLiquify) {

            ERC20(address(this)).transfer(address(addLiquidityHelper), ERC20(address(this)).balanceOf(address(this)));
            // send all tokens to add liquidity with, we are refunded any that aren't used.
            addLiquidityHelper.arcadiumETHLiquidityWithBuyBack{value: address(this).balance}(BURN_ADDRESS);
        }
    }

    /**
     * @dev unenchant the lp token into its original components.
     * Can only be called by the current operator.
     */
    function swapLpTokensForFee(address token, uint256 amount) internal {
        require(IERC20(token).approve(address(arcadiumSwapRouter), amount), '!approved');

        IUniswapV2Pair lpToken = IUniswapV2Pair(token);

        uint256 token0BeforeLiquidation = IERC20(lpToken.token0()).balanceOf(address(this));
        uint256 token1BeforeLiquidation = IERC20(lpToken.token1()).balanceOf(address(this));

        // make the swap
        arcadiumSwapRouter.removeLiquidity(
            lpToken.token0(),
            lpToken.token1(),
            amount,
            0,
            0,
            address(this),
            block.timestamp
        );

        uint256 token0FromLiquidation = IERC20(lpToken.token0()).balanceOf(address(this)) - token0BeforeLiquidation;
        uint256 token1FromLiquidation = IERC20(lpToken.token1()).balanceOf(address(this)) - token1BeforeLiquidation;

        address tokenForMyFriendsUSDCReward = lpToken.token0();
        address tokenForArcadiumAMMReward = lpToken.token1();

        // If we already have, usdc, save a swap.
       if (lpToken.token1() == address(usdcRewardCurrency)){

            (tokenForArcadiumAMMReward, tokenForMyFriendsUSDCReward) = (tokenForMyFriendsUSDCReward, tokenForArcadiumAMMReward);
        } else if (lpToken.token0() == arcadiumSwapRouter.WETH()){
            // if one is weth already use the other one for myfriends and
            // the weth for arcadium AMM to save a swap.

            (tokenForArcadiumAMMReward, tokenForMyFriendsUSDCReward) = (tokenForMyFriendsUSDCReward, tokenForArcadiumAMMReward);
        }

        // send myfriends all of 1 half of the LP to be convereted to USDC later.
        IERC20(tokenForMyFriendsUSDCReward).safeTransfer(address(myFriends),
            tokenForMyFriendsUSDCReward == lpToken.token0() ? token0FromLiquidation : token1FromLiquidation);

        // send myfriends 50% share of the other 50% to give myfriends 75% in total.
        IERC20(tokenForArcadiumAMMReward).safeTransfer(address(myFriends),
            (tokenForArcadiumAMMReward == lpToken.token0() ? token0FromLiquidation : token1FromLiquidation)/2);

        swapDepositFeeForTokensInternal(tokenForArcadiumAMMReward, 0, arcadiumSwapRouter.WETH());
    }

    /**
     * @dev sell all of a current type of token for weth, to be used in arcadium liquidity later.
     * Can only be called by the current operator.
     */
    function swapDepositFeeForETH(address token, uint8 tokenType) external onlyOwner {
        uint256 usdcValue = arcadiumToolBox.getTokenUSDCValue(IERC20(token).balanceOf(address(this)), token, tokenType, false, address(usdcRewardCurrency));

        // If arcadium or weth already no need to do anything.
        if (token == address(this) || token == arcadiumSwapRouter.WETH())
            return;

        // only swap if a certain usdc value
        if (usdcValue < usdcSwapThreshold)
            return;

        swapDepositFeeForTokensInternal(token, tokenType, arcadiumSwapRouter.WETH());
    }

    function swapDepositFeeForTokensInternal(address token, uint8 tokenType, address toToken) internal {
        uint256 totalTokenBalance = IERC20(token).balanceOf(address(this));

        // can't trade to arcadium inside of arcadium anyway
        if (token == toToken || totalTokenBalance == 0 || toToken == address(this))
            return;

        if (tokenType == 1) {
            swapLpTokensForFee(token, totalTokenBalance);
            return;
        }

        require(IERC20(token).approve(address(arcadiumSwapRouter), totalTokenBalance), "!approved");

        // generate the arcadiumSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = toToken;

        try
            // make the swap
            arcadiumSwapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                totalTokenBalance,
                0, // accept any amount of tokens
                path,
                address(this),
                block.timestamp
            )
        { /* suceeded */ } catch { /* failed, but we avoided reverting */ }

        // Unfortunately can't swap directly to arcadium inside of arcadium (Uniswap INVALID_TO Assert, boo).
        // Also dont want to add an extra swap here.
        // Will leave as WETH and make the arcadium Txn AMM utilise available WETH first.
    }

    // To receive ETH from arcadiumSwapRouter when swapping
    receive() external payable {}

    /**
     * @dev Update the swapAndLiquifyEnabled.
     * Can only be called by the current operator.
     */
    function updateSwapAndLiquifyEnabled(bool _enabled) external onlyOperator {
        swapAndLiquifyEnabled = _enabled;

        emit SetSwapAndLiquifyEnabled(swapAndLiquifyEnabled);
    }

    /**
     * @dev Update the transfer tax rate.
     * Can only be called by the current operator.
     */
    function updateTransferTaxRate(uint16 _transferTaxRate, uint16 _extraTransferTaxRate) external onlyOperator {
        require(_transferTaxRate + _extraTransferTaxRate  <= MAXIMUM_TRANSFER_TAX_RATE,
            "!valid");
        transferTaxRate = _transferTaxRate;
        extraTransferTaxRate = _extraTransferTaxRate;

        emit TransferFeeChanged(transferTaxRate, extraTransferTaxRate);
    }

    /**
     * @dev Update the excludeFromMap
     * Can only be called by the current operator.
     */
    function updateFeeMaps(address _contract, bool fromExcluded, bool toExcluded, bool fromHasExtra, bool toHasExtra) external onlyOperator {
        excludeFromMap[_contract] = fromExcluded;
        excludeToMap[_contract] = toExcluded;
        extraFromMap[_contract] = fromHasExtra;
        extraToMap[_contract] = toHasExtra;

        emit UpdateFeeMaps(_contract, fromExcluded, toExcluded, fromHasExtra, toHasExtra);
    }

    /**
     * @dev Update the swap router.
     * Can only be called by the current operator.
     */
    function updateArcadiumSwapRouter(address _router) external onlyOperator {
        require(_router != address(0), "!!0");
        require(address(arcadiumSwapRouter) == address(0), "!unset");

        arcadiumSwapRouter = IUniswapV2Router02(_router);
        arcadiumSwapPair = IUniswapV2Factory(arcadiumSwapRouter.factory()).getPair(address(this), arcadiumSwapRouter.WETH());

        require(address(arcadiumSwapPair) != address(0), "matic pair !exist");

        emit SetArcadiumRouter(address(arcadiumSwapRouter), arcadiumSwapPair);
    }

    /**
     * @dev Returns the address of the current operator.
     */
    function operator() public view returns (address) {
        return _operator;
    }

    /**
     * @dev Transfers operator of the contract to a new account (`newOperator`).
     * Can only be called by the current operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        require(newOperator != address(0), "!!0");
        _operator = newOperator;

        emit SetOperator(_operator);
    }
}
