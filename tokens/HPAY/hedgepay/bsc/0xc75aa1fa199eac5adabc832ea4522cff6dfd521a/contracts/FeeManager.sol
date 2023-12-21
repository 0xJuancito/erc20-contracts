// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFeeManager.sol";
import "./lib/SwapUtils.sol";
import "../interfaces/IFundManager.sol";


contract FeeManager is IFeeManager, Ownable {
    //  Should we swap the fee
    bool public swapFees = false;

    //Dev wallet cut from fees in %
    uint8 public DEV_ALLOCATION = 14;

    // Marketing wallet cut from fees in %
    uint8 public MARKETING_ALLOCATION = 20;

    // Fund Manager cut from fees in %
    uint8 public INVESTMENT_ALLOCATION = 66;

    // The router used to swap the fee into BNB or stable coin
    IUniswapV2Router02 public router;

    // The dev wallet
    address public devAddress;

    // Marketing wallet
    address public marketingAddress;

    // The Fund Manager Contract instance
    IFund public investmentAddress;

    ERC20 public token;
    ERC20 public busd = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    modifier addressesAreSet() {
        require(devAddress != address(0), "Dev address cannot be 0");
        require(marketingAddress != address(0), "Marketing address cannot be 0");
        require(address(investmentAddress) != address(0),"Investment address cannot be 0");
        _; 
    }

    constructor(ERC20 _token, IUniswapV2Router02 _router) {
        token = _token;
        router = _router;
    }

    function processFee() external override  {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Token balance cannot be 0 when processing");

        if(swapFees){
            // Swap the tokens to BUSD use a 1% slippage
            try SwapUtils.swapTokensForTokens(router, token, busd, balance, 100) {
                distributeBusdFees();
            } catch { 
                distributeFees();
            }
        } else {
            distributeFees();
        }
    }

    function processBusdFee(uint256 amount) external override {
        busd.transferFrom(address(msg.sender), address(this), amount);
        distributeBusdFees();
    }

    function distributeBusdFees() override public addressesAreSet() {
        uint256 amount = busd.balanceOf(address(this));

        require(amount > 0, "Not enough balance");
      
        // Calculate amounts to be received by each of the wallets
        (uint256 devTokens ,uint256 marketingTokens ,uint256 investmentTokens ) = calculateFeeDistribution(amount);
        

        busd.transfer(devAddress, devTokens);
        busd.transfer(marketingAddress, marketingTokens);

        busd.increaseAllowance(address(investmentAddress), investmentTokens);
        investmentAddress.investBUSD(investmentTokens);
    }

    function distributeETHFees() override public addressesAreSet() {
        uint256 ethBalance = address(this).balance;

        require(ethBalance > 0, "Not enough balance");
        // Calculate amounts to be received by each of the wallets
        (uint256 devTokens ,uint256 marketingTokens ,uint256 investmentTokens ) = calculateFeeDistribution(ethBalance);
        
        // Transfer the tokens
        payable(devAddress).transfer(devTokens);
        payable(marketingAddress).transfer(marketingTokens);
        investmentAddress.invest{value: investmentTokens}();
    }

    function distributeFees() public addressesAreSet() { 
        uint256 balance = token.balanceOf(address(this));

        require(balance > 0, "Not enough balance");
        token.transfer(marketingAddress, balance / 2);
        token.transfer(devAddress, token.balanceOf(address(this)));
    }

    function calculateFeeDistribution(uint256 amount) internal view returns(uint256, uint256, uint256) {
        uint256 devTokens = (amount * DEV_ALLOCATION) / 100;
        uint256 marketingTokens = (amount * MARKETING_ALLOCATION) / 100;
        uint256 investmentTokens = (amount * INVESTMENT_ALLOCATION) / 100;
        return (devTokens, marketingTokens, investmentTokens);
    }

    function setDevAddress(address newAddress) external onlyOwner { 
        require(address(0) != newAddress, "New address cannot be 0");
        require(devAddress != newAddress, "New address is the same as old address");
        devAddress = newAddress;
    }

    function setMarketingAddress(address newAddress) external onlyOwner { 
        require(address(0) != newAddress, "New address cannot be 0");
        require(marketingAddress != newAddress, "New address is the same as old address");
        marketingAddress = newAddress;
    }

    function setInvestmentAddress(address newAddress) external onlyOwner {
        require(address(0) != newAddress, "New address cannot be 0");
        require(address(investmentAddress) != newAddress, "New address is the same as old address");
        investmentAddress = IFund(newAddress);
    }

    function setTokenAddress(address newAddress) external onlyOwner {
        require(address(0) != newAddress, "New address cannot be 0");
        require(address(token) != newAddress,"New address is the same as old address");
        token = ERC20(newAddress);
    }

    function setAllocation(uint8 dev, uint8 marketing, uint8 investment) external onlyOwner {
        require( dev + marketing + investment == 100, "Ivalid distribution");
        DEV_ALLOCATION = dev;
        MARKETING_ALLOCATION = marketing;
        INVESTMENT_ALLOCATION = investment;
    }

    function setFeeSwapStatus(bool status) external onlyOwner {
        require(status != swapFees, "Status already set");
        swapFees = status;
    }

    function setRouterAddress(address newAddress) public onlyOwner {
        require(address(0) != newAddress, "New address cannot be 0");
        require(address(router) != newAddress, "New address is the same as old address");
        router = IUniswapV2Router02(newAddress);
    }

    function destroy() external onlyOwner {
        // Distribute any remaning tokens  
        uint256 tokenBalance = token.balanceOf(address(this));

        require(tokenBalance == 0 , "Contract still has tokens");
        require(busd.balanceOf(address(this)) == 0 , "Contract still has busd");

        // Call self destruct and send remaing ETH to owner
        selfdestruct(payable(owner()));
    }

    receive() external payable {} 
}
