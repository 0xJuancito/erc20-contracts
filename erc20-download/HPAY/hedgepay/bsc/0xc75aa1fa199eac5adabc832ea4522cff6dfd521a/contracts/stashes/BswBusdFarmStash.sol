// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "../../interfaces/IMasterChef.sol";
import "../../interfaces/IBiswapPair.sol";
import "../../interfaces/IStash.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
    A rewards stasg that stakes the stashed values until they are claimed
    It uses the biswap BUSD-USDT farm to do so 
 */
contract BswBusdFarmStash is IRewardStash, AccessControl {
    IMasterChef public stakeContract;
    IBiswapPair public LPToken;

    uint256 public busdGeneratedLiquidity;
    uint256 public farmingPoolId = 1;

    // Bws tokems are recived as reward from the framing pool
    ERC20 public bsw;

    // Refernece to the USDT contract
    ERC20 public usdt;

    // Reference to the BUSD contract
    ERC20 public busd;

    // We use the router to swap our tokens as needed
    IUniswapV2Router02 public router;

    uint8 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "Fund: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    event UpdateRouterAddress(address oldAddress, address newAddress);

    constructor() {
        bsw = ERC20(0x965F527D9159dCe6288a2219DB51fc6Eef120dD1);
        usdt = ERC20(0x55d398326f99059fF775485246999027B3197955);
        busd = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
        LPToken = IBiswapPair(0xDA8ceb724A06819c0A5cDb4304ea0cB27F8304cF);
        stakeContract = IMasterChef(0xDbc1A13490deeF9c3C12b44FE77b503c1B061739);
        router = IUniswapV2Router02(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OWNER_ROLE, msg.sender);
    }

    // Use this to stash busd with this srategy
    function stash(uint256 value) external override {
        uint256 pendingBSW = stakeContract.pendingBSW(
            farmingPoolId,
            address(this)
        );

        // Claim any farming rewards. The busd will be added back into the farm togheder with the stashed value
        if (pendingBSW > 1) {
            claimFarmingReward();
        }

        // Transfer the busd from the sender
        busd.transferFrom(address(msg.sender), address(this), value);

        uint256 currentBalance = busd.balanceOf(address(this));

        if(currentBalance == 0) {
            return;
        }

        // Swap half of BUSD capital to USDT.
        uint256 capitalHalf = busd.balanceOf(address(this)) / 2;
        sawpBUSDFotUsdt(capitalHalf);

        // We add the BUSD and USDT capital as liquidity and stake that liquidity
        uint256 liquidity = addLiquidityAndStake();

        busdGeneratedLiquidity += liquidity;
    }

    // Use this to unstash busd
    function unstash(uint256 busdValue)
        external
        override
        onlyRole(MANAGER_ROLE)
        lock
    {
    
        _unstash(busdValue);

        require(
            busdValue <= busd.balanceOf(address(this)),
            "Insufficient balance"
        );

        busd.transfer(msg.sender, busdValue);
    }

    function _unstash(uint256 busdValue) private {
        // Calculate how much we need to unstake to cover the unstash value
        uint256 lpAmount = busdValue / lpUsdValue(1);
        unstakeAndRemoveLiquidity(lpAmount);
    }

    function pendingProfit() external view returns (uint256) {
        uint256 pendingBSW = stakeContract.pendingBSW(
            farmingPoolId,
            address(this)
        );

        if(pendingBSW == 0) {
            return 0;
        }
        address[] memory path = new address[](3);
        path[0] = address(bsw);
        path[1] = router.WETH();
        path[2] = address(busd);
        uint256 profit = router.getAmountsOut(pendingBSW, path)[2];
        return profit;
    }

    // Claims the BSW reward generated from farming and swaps it to BUSD
    function claimFarmingReward() public {
        stakeContract.withdraw(farmingPoolId, 0);
        swapRewardForBUSD();
    }

    function stashValue() external view override returns (uint256) {
        (uint256 lpAmount, ) = stakeContract.userInfo(
            farmingPoolId,
            address(this)
        );

        return lpUsdValue(lpAmount);
    }

    function lpUsdValue(uint256 lpAmount) public pure returns (uint256) {
        return lpAmount * 2;
    }

    function addLiquidityAndStake() private returns (uint256 stakedLiquidity) {
        // Add the available BUSD and USDT to the liquidity pool and stake that liquidity
        uint256 liquidity = addLiquidity();
        stakeLp();
        return liquidity;
    }

    // Unstake the liquidity points
    function unstakeAndRemoveLiquidity(uint256 amount) private {
        unstakeLp(amount);
        removeLiquidity(amount);
    }

    function sawpBUSDFotUsdt(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(busd);
        path[1] = address(usdt);

        busd.increaseAllowance(address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapUSDTFroBUSD(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(busd);

        usdt.increaseAllowance(address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapRewardForBUSD() private {
        uint256 tokenAmount = bsw.balanceOf(address(this));
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(bsw);
        path[1] = address(busd);

        bsw.increaseAllowance(address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function stakeLp() private {
        uint256 lpAmount = LPToken.balanceOf(address(this));
        LPToken.approve(address(stakeContract), lpAmount);

        stakeContract.deposit(farmingPoolId, lpAmount);
    }

    function unstakeLp(uint256 amount) private {
        stakeContract.withdraw(farmingPoolId, amount);
    }

    function addLiquidity() private returns (uint256 addedLiquidity) {
        uint256 busdAmount = busd.balanceOf(address(this));
        uint256 usdtAmount = usdt.balanceOf(address(this));
        // approve token transfer to cover all possible scenarios
        busd.increaseAllowance(address(router), busdAmount);
        usdt.increaseAllowance(address(router), usdtAmount);

        // add the liquidity
        (, , uint256 liquidity) = router.addLiquidity(
            address(busd),
            address(usdt),
            busdAmount,
            usdtAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );

        return liquidity;
    }

    function removeLiquidity(uint256 lpAmount) private {
        LPToken.approve(address(router), lpAmount);

        // add the liquidity
        router.removeLiquidity(
            address(busd),
            address(usdt),
            lpAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );

        swapUSDTFroBUSD(usdt.balanceOf(address(this)));
    }

    function setRouterAddress(address newAddress) public onlyRole(OWNER_ROLE) {
        require(
            address(router) != newAddress,
            "New address is the same as old address"
        );
        require(
            address(0) != newAddress,
            "Router address cannot be address(0)"
        );
        emit UpdateRouterAddress(address(router), newAddress);
        router = IUniswapV2Router02(newAddress);
    }

    // Use this function to migrate the capital to another address
    function migrateCapital(address _newStashAddress, uint256 busdAmount)
        external
        onlyRole(OWNER_ROLE)
    {
        _unstash(busdAmount);

        require(
            busdAmount <= busd.balanceOf(address(this)),
            "Insufficient balance"
        );

        busd.transfer(_newStashAddress, busdAmount);
    }

    // Migrate all the capital to a new address
    function migrateAndDestory(address _newStashAddress) external onlyRole(OWNER_ROLE)
    {
        (uint256 lpAmount, ) = stakeContract.userInfo(
            farmingPoolId,
            address(this)
        );

        claimFarmingReward();
        unstakeAndRemoveLiquidity(lpAmount);

        require(
            bsw.balanceOf(address(this)) == 0,
            "BSW Balance != 0 cannot cannot destroy"
        );

        require(
            usdt.balanceOf(address(this)) == 0,
            "USDT Balance != 0 cannot destory"
        );

        busd.transfer(_newStashAddress, busd.balanceOf(address(this)));

        // Self destruct and transfer any ETH to the owner
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {}
}
