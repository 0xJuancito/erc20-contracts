// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// @title ERC20 with buy and sell fees
contract RAMBE is ERC20, Ownable2Step {
    /// custom errors
    error CannotRemoveMainPair();
    error ZeroAddressNotAllowed();
    error FeesLimitExceeds();
    error SenderIsBlacklisted();
    error ReceiverIsBlacklisted();
    error CannotBlacklistLPPair();
    error UpdateBoolValue();
    error CannotClaimNativeToken();
    error ERC20TokenClaimFailed();
    
    /// @notice Max limit on Buy / Sell fees
    uint256 public constant MAX_FEE_LIMIT = 10; 
    /// @notice max total supply 1 billion tokens (18 decimals)
    uint256 private maxSupply = 1e9 * 1e18; 
    /// @notice swap threshold at which collected fees tokens are swapped for ether, autoLP
    uint256 public swapTokensAtAmount = 1e3 * 1e18;
    /// @notice check if it's a swap tx
    bool private inSwap = false;
    
    /// @notice struct buy fees variable
    /// marketing: marketing fees
    /// autoLP: liquidity fees
    struct BuyFees {
        uint16 marketing;
        uint16 autoLP;
    }
    /// @notice struct sell fees variable
    /// marketing: marketing fees
    /// autoLP: liquidity fees
    struct SellFees {
        uint16 marketing;
        uint16 autoLP;
    }
    
    /// @notice buyFees variable
    BuyFees public buyFee;
    /// @notice sellFees variable
    SellFees public sellFee;
    
    /// @notice totalBuyFees
    uint256 private totalBuyFee;
    /// @notice totalSellFees
    uint256 private totalSellFee;
    
    /// @notice marketingWallet
    address public marketingWallet;
    /// @notice uniswap V2 router address
    IUniswapV2Router02 public immutable uniswapV2Router;
    /// @notice uniswap V2 Pair address
    address public uniswapV2Pair;
    
    /// @notice mapping to manager liquidity pairs
    mapping(address => bool) public isAutomatedMarketMaker;
    /// @notice mapping to manage excluded address from/to fees
    mapping(address => bool) public  isExcludedFromFees;
    /// @notice mapping to manage blacklisted users
    mapping(address => bool)public  isBlacklisted;

    //// EVENTS //// 
    event BuyFeesUpdated(uint16 indexed marketingFee, uint16 indexed liquidityFee);
    event SellFeesUpdated(uint16 indexed marketingFee, uint16 indexed liquidityFee);
    event FeesSwapped(uint256 indexed ethForLiquidity, uint256 indexed tokensForLiquidity,  uint256 indexed ethForMarketing);

    
    /// @dev create an erc20 token using openzeppeling ERC20, Ownable2Step
    /// uses uniswap router and factory interface
    /// set uniswap router, create pair, initialize buy, sell fees, marketingWallet values
    /// excludes the token, marketingWallet and owner address from fees
    /// and mint all the supply to owner wallet.
    constructor () ERC20("Harambe Token", "RAMBE"){
      uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
      uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
      isAutomatedMarketMaker[uniswapV2Pair] = true;

      buyFee.marketing = 4;
      buyFee.autoLP = 1;
      totalBuyFee = 5;

      sellFee.marketing = 4;
      sellFee.autoLP = 1;
      totalSellFee = 5;
      
      marketingWallet = 0xa0E13E7CA54274173931349e4c3DA1223d4F701d;

      isExcludedFromFees[address(this)] = true;
      isExcludedFromFees[marketingWallet] = true;
      isExcludedFromFees[owner()] = true;
      _mint(msg.sender, maxSupply);
    }

    /// modifier  ///
     modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
    
    /// receive external ether
    receive () external payable {}

    /// @dev owner can claim other erc20 tokens, if accidently sent by someone
    /// @param _token: token address to be rescued
    /// @param _amount: amount to rescued
    /// Requirements --
    /// Cannot claim native token
    function claimOtherERC20 (address _token, uint256 _amount) external onlyOwner {
        if(_token == address(this)) {
            revert CannotClaimNativeToken();
        }
        IERC20 tkn = IERC20(_token);
        bool success = tkn.transfer(owner(), _amount);
        if(!success){
            revert ERC20TokenClaimFailed();
        }
    }
    
    /// @dev exclude or include a user from/to fees
    /// @param user: user address
    /// @param value: boolean value. true means excluded. false means included
    /// Requirements --
    /// zero address not allowed
    /// if a user is excluded already, can't exlude him again
    function excludeFromFees (address user, bool value) external onlyOwner {
        if(user == address(0)){
           revert  ZeroAddressNotAllowed();
        }
        if(isExcludedFromFees[user] == value){
           revert UpdateBoolValue();
        }
        isExcludedFromFees[user] = value;
    }
    

    /// @dev blacklist or unblacklist users
    /// @param account: address to be blacklisted or unblacklisted
    /// @param value: boolean value, true means blacklisted, false means unblacklisted
    /// Requirements --
    /// address should not be zero
    /// Can not blacklist pairs
    /// can not blacklist already blacklisted address and vice versa
    function manageBlacklistAddress(address account, bool value) external onlyOwner {
        if(account == address(0)){
            revert ZeroAddressNotAllowed();
        }
        if(isAutomatedMarketMaker[account]){
            revert CannotBlacklistLPPair();
        }
        if(isBlacklisted[account] == value){
            revert UpdateBoolValue();
        }
        isBlacklisted[account] = value;
    }

    /// @dev add or remove new pairs
    /// @param _newPair: address to be added or removed as pair
    /// @param value: boolean value, true means blacklisted, false means unblacklisted
    /// Requirements --
    /// address should not be zero
    /// Can not remove main pair
    /// can not add already added pairs  and vice versa
    function manageLiquidityPairs (address _newPair, bool value) external onlyOwner {
        if(_newPair == address(0)){
            revert ZeroAddressNotAllowed();
        }
        if(_newPair == uniswapV2Pair){
            revert CannotRemoveMainPair();
        }
        if(isAutomatedMarketMaker[_newPair] == value){
            revert UpdateBoolValue();
        }
        isAutomatedMarketMaker[_newPair] = value;
        
    }
    
    /// @dev update marketing fee wallet
    /// @param _newMarketingWallet: new marketing wallet address
    /// Requirements -
    /// Address should not be zero
    function updateMarketingWallet(address _newMarketingWallet) external onlyOwner {
        if(_newMarketingWallet == address(0)){
            revert ZeroAddressNotAllowed();
        }
        marketingWallet = _newMarketingWallet;
    }

    /// @dev update buy fees
    /// @param _marketing: marketing fees
    /// @param _autoLP: liquidity fees
    /// Requirements --
    /// total Buy fees must be less than equals to MAX_FEE_LIMIT (10%);
    function updateBuyFees (uint16 _marketing, uint16 _autoLP) external onlyOwner {
        if(_marketing + _autoLP > MAX_FEE_LIMIT){
            revert FeesLimitExceeds();
        }
        buyFee.marketing = _marketing;
        buyFee.autoLP = _autoLP;
        totalBuyFee = _marketing + _autoLP;
        emit BuyFeesUpdated(_marketing, _autoLP);

    }
    
    /// @dev update sell fees
    /// @param _marketing: marketing fees
    /// @param _autoLP: liquidity fees
    /// Requirements --
    /// total Sell fees must be less than equals to MAX_FEE_LIMIT (10%);
    function updateSellFees (uint16 _marketing, uint16 _autoLP) external onlyOwner {
        if(_marketing + _autoLP > MAX_FEE_LIMIT){
            revert FeesLimitExceeds();
        }
        sellFee.marketing = _marketing;
        sellFee.autoLP = _autoLP;
        totalSellFee = _marketing + _autoLP;
        emit SellFeesUpdated(_marketing, _autoLP);

    }

    /// @notice manage transfers, fees
    /// see {ERC20 - _transfer}
    /// requirements -- 
    /// from or to should not be zero
    /// from or to should not be blacklisted
    function _transfer (address from, address to, uint256 amount) internal override {
       if(from == address(0)){
        revert ZeroAddressNotAllowed();
       } 
       if(to == address(0)){
        revert ZeroAddressNotAllowed();
       }
       if(isBlacklisted[from]){
        revert SenderIsBlacklisted();
       }
       if(isBlacklisted[to]){
        revert ReceiverIsBlacklisted();
       }
       if(amount == 0){
        super._transfer(from, to, 0);
        return;
       }
       uint256 contractBalance = balanceOf(address(this)); 
       bool canSwapped = contractBalance >= swapTokensAtAmount;
       if(canSwapped && !isAutomatedMarketMaker[from] && !inSwap && !isExcludedFromFees[from] && !isExcludedFromFees[to]){
          if(contractBalance > swapTokensAtAmount * 20){
             contractBalance = swapTokensAtAmount * 20;
            }
        swapAndLiquify(contractBalance);
       }
       
       bool takeFee = true;
       if(isExcludedFromFees[from] || isExcludedFromFees[to]){
        takeFee = false;
       }
       uint256 fees = 0;
       if(takeFee){
        if(isAutomatedMarketMaker[from] && totalBuyFee > 0){
            fees = (amount * totalBuyFee) / 100;
        }
        if(isAutomatedMarketMaker[to] && totalSellFee > 0){
            fees = (amount * totalSellFee) / 100;
        }
        super._transfer(from, address(this), fees);
        amount = amount - fees;
       }
     super._transfer(from, to, amount);
    }
    
    /// @notice swap the collected fees to eth / add liquidity
    /// after conversion, it sends eth to marketing wallet, add auto liquidity
    /// @param tokenAmount: tokens to be swapped appropriately as per fee structure
    function swapAndLiquify (uint256 tokenAmount) private lockTheSwap {
        if(totalBuyFee + totalSellFee == 0){
            swapTokensForEth(tokenAmount);
            bool m;
           (m,) = payable(marketingWallet).call{value: address(this).balance}("");
        } else {
        uint256 marketingTokens = ((buyFee.marketing + sellFee.marketing) * tokenAmount) / (totalBuyFee + totalSellFee);
        uint256 liquidityTokens = tokenAmount - marketingTokens;
        uint256 liquidityTokensHalf = liquidityTokens / 2;
        uint256 swapTokens = tokenAmount - liquidityTokensHalf;
        uint256 ethBalanceBeforeSwap = address(this).balance;
        swapTokensForEth(swapTokens);
        uint256 ethBalanceAfterSwap = address(this).balance - ethBalanceBeforeSwap;
        uint256 ethForLiquidity = (liquidityTokensHalf * ethBalanceAfterSwap) /swapTokens;
        if(ethForLiquidity > 0 && liquidityTokensHalf > 0){
            addLiquidity(liquidityTokensHalf, ethForLiquidity);
        }
        bool success;
        uint256 marketingEth = address(this).balance;
        if(marketingEth > 0){
          (success,) = payable(marketingWallet).call{value: marketingEth}("");
        }
        emit FeesSwapped(ethForLiquidity, liquidityTokensHalf, marketingEth);
        }

    }

    /// @notice manages tokens conversion to eth
    /// @param tokenAmount: tokens to be converted to eth
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        
        if(allowance(address(this), address(uniswapV2Router)) < tokenAmount){
        _approve(address(this), address(uniswapV2Router), type(uint256).max);
        }

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    
    /// @notice manage autoLP (liquidity addition)
    /// @param tokenAmount: tokens to be added to liquidity
    /// @param ethAmount: eth to be added to liquidity
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(), // LP tokens recevier
            block.timestamp
        );
    }


}

