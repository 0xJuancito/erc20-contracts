// SPDX-License-Identifier: ISC

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../../interfaces/IFundManager.sol";
import "../lib/SwapUtils.sol";
import "../../interfaces/IFeeManager.sol";

contract Exchange is Ownable {
    event TokensPurchased(
        address purchaser,
        address beneficiary,
        uint256 value,
        uint256 amount
    );

    event TokensSold(
        address seller,
        address beneficiary,
        uint256 value,
        uint256 amount
    );

    bool public feeDistributionEnabled;
    uint256 public buyFee = 80;
    uint256 public sellFee = 120;

    // Reference to the BUSD contract
    ERC20 public busd;
    ERC20 public token;

    // We use the router to swap our tokens as needed
    IUniswapV2Router02 public router;

    // Fee manager address
    IFeeManager public feeManager;

    constructor(address _token, address _feeManager) {
        require(_token != address(0), "EX: token is the zero address");
        require(_feeManager != address(0), "EX: feeManager is the zero address");

        token = ERC20(_token);
        feeManager = IFeeManager(_feeManager);
        feeDistributionEnabled = true;
        busd = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    function buy(uint256 amount, uint256 minTokens) external {
        address beneficiary = msg.sender;
        _preValidateTransaction(beneficiary, amount);
        busd.transferFrom(address(msg.sender), address(this), amount);

        uint256 fee = (amount * buyFee) / 1000;
        uint256 exchangeAmount = amount - fee;
        uint256 result = swapExactERC20(busd, token, exchangeAmount, minTokens);
        token.transfer(beneficiary, result);
        busd.transfer(address(feeManager), busd.balanceOf(address(this)));
        if(feeDistributionEnabled) {
            feeManager.distributeBusdFees();
        }
        emit TokensPurchased(_msgSender(), beneficiary, amount, minTokens);
    }

    function buyWithChainCoin(uint256 minTokens) external payable {
        uint256 weiAmount = msg.value;
        _preValidateTransaction(msg.sender, weiAmount);
        uint256 fee = (weiAmount * buyFee) / 1000;
        uint256 exchangeAmount = weiAmount - fee;
      
        uint256 result = swapExactETHForTokens(token, exchangeAmount, minTokens);
        token.transfer(msg.sender, result);
        payable(address(feeManager)).transfer(address(this).balance);
        if(feeDistributionEnabled) {
            feeManager.distributeETHFees();
        }
        emit TokensPurchased(_msgSender(), msg.sender, weiAmount, minTokens);
    }

    function sellTokens(uint256 amount, uint256 minAmount) external {
        address beneficiary = address(msg.sender);
        _preValidateTransaction(beneficiary, amount);
        _drainTokens(msg.sender, amount);

        uint256 output = swapExactERC20(token, busd, amount, minAmount);
        uint256 fee = (output * sellFee) / 1000;

        busd.transfer(beneficiary, output - fee);
        busd.transfer(address(feeManager), busd.balanceOf(address(this)));

        emit TokensSold(_msgSender(), beneficiary, output - fee, amount);
    }

    function sellTokensForChainCoin(uint256 amount, uint256 minEth) external {
        address beneficiary = address(msg.sender);
        _preValidateTransaction(beneficiary, amount);
        _drainTokens(msg.sender, amount);

        uint256 output = swapExactTokensForETH(token, amount, minEth);
        uint256 fee = (output * sellFee) / 1000;

        payable(address(beneficiary)).transfer(output - fee);
        payable(address(feeManager)).transfer(address(this).balance);
        emit TokensSold(_msgSender(), beneficiary, output - fee, amount);
    }

    function ethRate() public view returns (uint256 buyRate, uint256 sellRate) {
        address[] memory path = new address[](3);
        path[0] = router.WETH();
        path[1] = address(busd);
        path[2] = address(token);

        buyRate = router.getAmountsOut(10**token.decimals(), path)[2];

        path[0] = address(token);
        path[1] = address(busd);
        path[2] = router.WETH();

        sellRate = router.getAmountsOut(10**token.decimals(), path)[2];
    }

    function busdRate() public view returns (uint256 buyRate, uint256 sellRate) {
        address[] memory path = new address[](2);

        path[0] = address(busd);
        path[1] = address(token);

        buyRate = router.getAmountsOut(10**token.decimals(), path)[1];
        
        path[0] = address(token);
        path[1] = address(busd);

        sellRate = router.getAmountsOut(10**token.decimals(), path)[1];
    }

    function _preValidateTransaction(address beneficiary, uint256 amount) internal pure {
        require(beneficiary != address(0), "Beneficiary is the zero address"); 
        require(amount > 0, "Amount is 0");
    }

    function _drainTokens(address seller, uint256 tokenAmount) internal {
        token.transferFrom(seller, address(this), tokenAmount);
    }

    function swapExactTokensForETH( ERC20 _token, uint256 amount, uint256 minAmount) internal returns (uint256) {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](3);
        path[0] = address(_token);
        path[1] = address(busd);
        path[2] = router.WETH();

        _token.increaseAllowance(address(router), amount);
        uint256[] memory amounts = router.swapExactTokensForETH(amount, minAmount, path, address(this), block.timestamp);

        return amounts[2];
    }

    function swapExactETHForTokens( ERC20 _token, uint256 ethAmount, uint256 minAmount) internal returns (uint256) {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](3);
        path[0] = router.WETH();
        path[1] = address(busd);
        path[2] = address(_token);

        uint256[] memory amounts = router.swapExactETHForTokens{
            value: ethAmount
        }(minAmount, path, address(this), block.timestamp);

        return amounts[2];
    }

    function swapExactERC20( ERC20 from, ERC20 to, uint256 amount, uint256 minAmount) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(from);
        path[1] = address(to);

        from.increaseAllowance(address(router), amount);
        // make the swap
        uint256 resultAmount = router.swapExactTokensForTokens(
            amount,
            minAmount,
            path,
            address(this),
            block.timestamp
        )[1];

        return resultAmount;
    }

    function setFeeManager(address newAddress) external onlyOwner {
        require(address(0) != newAddress, "Fee Manager cannot be 0");
        require(address(feeManager) != newAddress, "Fee Manager same old"); 
        feeManager = IFeeManager(newAddress);
    }

    function setFeeDistributionEnabled(bool status) external onlyOwner {
        require(status != feeDistributionEnabled, "Fee Manager same old");
        feeDistributionEnabled = status;
    }

    function destroy() external onlyOwner {
        selfdestruct(payable(owner()));
    }

    function setFee(uint256 _buyFee, uint256 _sellFee) external onlyOwner { 
        require(_buyFee <= 1000 && _sellFee <= 1000, "Out of bounds");
        buyFee = _buyFee;
        sellFee = _sellFee;
    }
    
    receive() external payable { }
}
