// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "../interfaces/IMasterChef.sol";
import "../interfaces/IBiswapPair.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IFundManager.sol";
import "../interfaces/IInvestmentStrategy.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
    Capital vault used to safely store our investment capital
 */
contract CapitalVault is IVault, Ownable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    ERC20 public busd = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    
    IFund public fund;
    modifier mustHaveFundSet() {
        require(address(fund) != address(0), "No Fund contract was set");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    function investCapitalIntoFund(uint256 amount) external mustHaveFundSet onlyRole(MANAGER_ROLE) {
        require(address(this).balance >= amount, "Insufficient balance");
        fund.invest{value: amount}();
    }

    function investBusdCapitalIntoFund(uint256 amount) external mustHaveFundSet onlyRole(MANAGER_ROLE) {
        require(busd.balanceOf(address(this)) >= amount, "Insufficient balance" );
        
        busd.increaseAllowance(address(fund), amount);
        fund.investBUSD(amount);
    }

    // Transfer ERC20 Asset out of the vault
    function transferERC20Asset(IERC20 asset, uint256 amount, address destination) external override onlyOwner {
        require(asset.balanceOf(address(this)) >= amount, "Insufficient balance");
        require(address(0) !=  destination, "Cannot send to 0 address");

        asset.safeTransfer(destination, amount);
        emit TransferERC20(destination, amount);
    }

    // Transfer ETH Asset out of the vault
    function transferETH(uint256 amount, address destination) external override onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance"); 
        payable(destination).transfer(amount);
    }

    // Inject Asset capital into a strategy
    function addAssetCapitalToStrategy(IInvestmentStrategy strategy, address assetAddress, uint256 amount) external override onlyRole(MANAGER_ROLE) {
        // Check to see if the strategy is registerd with the current fund 
        checkStrategy(address(strategy));
       
        ERC20 asset = ERC20(assetAddress);
        require(asset.balanceOf(address(this)) >= amount, "Insufficient balance");

        asset.increaseAllowance(address(strategy), amount);
        strategy.addAssetCapital(amount);
    }

    // Inject BUSD capital into a strategy
    function addBusdCapitalToStrategy(IInvestmentStrategy strategy, uint256 amount) external override onlyRole(MANAGER_ROLE) {
        // Check to see if the strategy is registerd with the current fund 
        checkStrategy(address(strategy));
       
        require(busd.balanceOf(address(this)) >= amount, "Insufficient balance");

        busd.increaseAllowance(address(strategy), amount);
        strategy.addBusdCapital(amount);
    }

    // Inject ETH capital into a strategy
    function addCapitalToStrategy(IInvestmentStrategy strategy, uint256 amount) external override onlyRole(MANAGER_ROLE) {
        checkStrategy(address(strategy));
       
        require(address(this).balance >= amount, "Insufficient balance");
        strategy.addCapital{value: amount}();
    }

    function lockedBusd() external view returns(uint256) {
        return busd.balanceOf(address(this));
    }

    function checkStrategy(address strategyAddress) internal view mustHaveFundSet {
        (,bool exists, ) = fund.getStrategyByAddress(strategyAddress);
        require(exists, "Strategy not registerd with current fund");
    }

    function setFundAddress(address newAddress) public onlyOwner {
        require(address(fund) != newAddress, "New address is the same as old address");
        require(address(0) != newAddress, "Fund address cannot be address(0)");
        fund = IFund(newAddress);
    }

    function destroy(address receiver) external onlyOwner {
        selfdestruct(payable(receiver)); 
    }
    
    receive() external payable {}
}
