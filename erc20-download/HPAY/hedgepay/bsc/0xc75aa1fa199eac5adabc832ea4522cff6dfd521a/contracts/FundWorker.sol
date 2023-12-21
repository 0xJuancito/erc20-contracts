// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Fund.sol";
import "./abstract/AbstractLock.sol";
import "./lib/FundWorkerUtils.sol";
import "./lib/SwapUtils.sol";
import "./HedgeToken.sol";
import "../interfaces/IFundProcessor.sol";


contract FundWorker is AccessControl, Lock, Pausable {
    FundWorkerUtils.FundWorkerState public state;

    bool public swap = false;

    // The router used to swap the fee into BNB or stable coin
    IUniswapV2Router02 public router;

    using FundWorkerUtils for FundWorkerUtils.FundWorkerState;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public tokenRewardAmount = 750 * 10 ** 18;
    uint256 public swapSlippage = 150; // 1.5% slippage

    uint256 public lastMint;
    address public splitterAddr;
    Fund public fund;
    HedgeToken public token;
    ERC20 public busd = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    
    event SwapFailed(address from, address to, uint256 amount, uint256 slippage);

    constructor(
        address fundAddress,
        address tokenAddress
    ) {
        fund = Fund(payable(fundAddress));
        token = HedgeToken(tokenAddress);
        state.batchSize = 5;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    function collectableProfits() external view returns (uint256 currentProfits, uint256 bounty) {
        currentProfits = state.pendingCollectableProfits(fund);
        bounty = (currentProfits * fund.collectProfitReward()) / 100;
        return (currentProfits, bounty / 100);
    }

    function collectProfits() external {
        uint256 reward = state.collectProfitBatch(fund);

        if (!swap) {
            busd.transfer(msg.sender, reward);
        } else {
            try SwapUtils.swapTokensForTokens(router, busd, token, reward, swapSlippage) {
                token.transfer(msg.sender, token.balanceOf(address(this)));
            } catch {
                emit SwapFailed(address(busd), address(token), reward, swapSlippage);
                busd.transfer(msg.sender, reward);
            }
        }

        if(willGetBonus()) {
            token.mint(msg.sender, tokenRewardAmount);
            lastMint = block.timestamp;
        }
        
        fund.updateRewardSnap();
    }

    function willGetBonus() public view returns (bool) {
        return block.timestamp - lastMint > 1 days && tokenRewardAmount > 0 ;
    } 

    function setBatchSize(uint8 batchSize) external onlyRole(MANAGER_ROLE) {
        require(batchSize > 0, "Batch cannot be 0");
        FundWorkerUtils.FundWorkerState storage st = state;
        st.batchSize = batchSize;
    }

    function setFundAddress(address newAddress) external onlyRole(MANAGER_ROLE) {
        require(address(fund) != newAddress,"New address is the same as old address");
        require(newAddress != address(0), "New address cannot be 0x00");
        fund = Fund(payable(newAddress));
    }

    function setSplitterAddress(address newAddress) external onlyRole(MANAGER_ROLE) {
        require(address(fund) != newAddress, "New address is the same as old address");
        require(newAddress != address(0), "New address cannot be 0x00");
        splitterAddr = newAddress;
    }

    function setRewards(uint256 reward) external onlyRole(MANAGER_ROLE) {
        tokenRewardAmount = reward;
    }

    function destroy(address receiver) external onlyRole(MANAGER_ROLE) {
        if (busd.balanceOf(address(this)) > 0) {
            busd.transfer(receiver, busd.balanceOf(address(this))); 
        }

        if (token.balanceOf(address(this)) > 0) {
            token.transfer(receiver, token.balanceOf(address(this)));
        }

        selfdestruct(payable(receiver));
    }
}
