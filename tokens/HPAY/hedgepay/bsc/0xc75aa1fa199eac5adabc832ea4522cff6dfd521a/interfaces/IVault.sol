// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;
import "./IInvestmentStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
   Stash rewards until they are ready to be claimed
*/
interface IVault {
  event TransferERC20(address asserAddress, uint256 amount);
  event TransferETH(uint256 amount);
  event AddCapital(IInvestmentStrategy strategyAddress, address assetAddress, uint256 amount);
  event AddETHCapital(IInvestmentStrategy strategyAddress, uint256 amount);
  event InvestBUSD(address fundAddress, uint256 amount);
  event InvestETH(address fundAddress, uint256 amount);
  
  // Add amount to stash
  function transferERC20Asset(IERC20 asset, uint256 amount, address destination) external ;

  // Remove amount from stash
  function transferETH(uint256 amount, address destination) external;

  // Inject capital into a strategy
  function addAssetCapitalToStrategy(IInvestmentStrategy strategy, address assetAddress, uint256 amount) external;
  function addBusdCapitalToStrategy(IInvestmentStrategy strategy, uint256 amount) external;
  function addCapitalToStrategy(IInvestmentStrategy strategy, uint256 amount) external;
}
