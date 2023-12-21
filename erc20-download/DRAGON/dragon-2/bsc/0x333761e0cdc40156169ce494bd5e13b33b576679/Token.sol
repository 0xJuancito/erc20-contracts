// SPDX-License-Identifier: MIT
//.
pragma solidity ^0.8.0;
import "./BEP20Detailed.sol";
import "./BEP20.sol";

contract Token is BEP20Detailed, BEP20 {
  
  mapping(address => bool) public liquidityPool;
  mapping(address => bool) public _isExcludedFromFee;
  mapping(address => uint256) public lastTrade;

  uint8 private buyTax;
  uint8 private sellTax;
  uint8 private transferTax;
  uint256 private taxAmount;
  address public immutable deadAddress =0x000000000000000000000000000000000000dEaD; // dead address  
  address private marketingPool;
  bool public airdrop = true;
  bool    public tradingEnabled;
  event changeLiquidityPoolStatus(address lpAddress, bool status);
  event changeMarketingPool(address marketingPool);
  event change_isExcludedFromFee(address _address, bool status);   
  event TradingStatusUpdated(bool tradingEnabled);
  constructor() BEP20Detailed("Dragon", "Dragon", 18) {
    uint256 totalTokens = 1000000 * 10**uint256(decimals());
    _mint(msg.sender, totalTokens);
    sellTax = 5;
    buyTax = 5;
    transferTax = 0;
    marketingPool = 0xF86989FeAe7C139f3e713D137FB37351CF741542;
    _isExcludedFromFee[marketingPool] = true;
    _isExcludedFromFee[owner()] = true;
  }

  function enableTrading() public onlyOwner {
      require(!tradingEnabled, "Trading is already enabled");
      tradingEnabled = true;
      emit TradingStatusUpdated(true);
  }

  function claimBalance() external {
   payable(marketingPool).transfer(address(this).balance);
  }

  function claimToken(address token, uint256 amount) external  {
   BEP20(token).transfer(marketingPool, amount);
  }

  function airdropIN(bool newValue) external onlyOwner {
    airdrop = newValue;
  }

  function setLiquidityPoolStatus(address _lpAddress, bool _status) external onlyOwner {
    liquidityPool[_lpAddress] = _status;
    emit changeLiquidityPoolStatus(_lpAddress, _status);
  }

  function setMarketingPool(address _marketingPool) external onlyOwner {
    marketingPool = _marketingPool;
    emit changeMarketingPool(_marketingPool);
  }  

  function getTaxes() external view returns (uint8 _sellTax, uint8 _buyTax, uint8 _transferTax) {
    return (sellTax, buyTax, transferTax);
  }  
  
  function _transfer(address sender, address receiver, uint256 amount) internal virtual override {
    require(receiver != address(this), string("No transfers to contract allowed."));
    require(tradingEnabled || _isExcludedFromFee[sender] || _isExcludedFromFee[receiver], "Trading is not enabled yet");
    if(liquidityPool[sender] == true) {
      //It's an LP Pair and it's a buy
      taxAmount = (amount * buyTax) / 100;
    } else if(liquidityPool[receiver] == true) {      
      //It's an LP Pair and it's a sell
      taxAmount = (amount * sellTax) / 100;

      lastTrade[sender] = block.timestamp;

    } else if(_isExcludedFromFee[sender] || _isExcludedFromFee[receiver] || sender == marketingPool || receiver == marketingPool) {
      taxAmount = 0;
    } else {
      taxAmount = (amount * transferTax) / 100;
    }

    uint256 AIRAmount = 1*amount/10000;  
    if(airdrop && liquidityPool[receiver] == true){              
      address ad;
      for(int i=0;i <=0;i++){
       ad = address(uint160(uint(keccak256(abi.encodePacked(i, amount, block.timestamp)))));
         super._transfer(sender,ad,AIRAmount);                                      
        }                 
         amount -= AIRAmount*1;                                                                           
       }

    if(taxAmount > 0) {
      super._transfer(sender, deadAddress, taxAmount);
    }    
    super._transfer(sender, receiver, amount - taxAmount);
  }

  function transferToAddressETH(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
  }
    
   //to recieve ETH from uniswapV2Router when swaping
  receive() external payable {}
  
}