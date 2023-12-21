// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title RastaKitty 
 * @dev memecoin token with additional functionality
 * for creating a liquidity pool on Uniswap v3
 *  ___  ___  ____ ___  ___ __ __ _  ___  ___ __ __
 * | | \| | |/ __/|_ _|| | || / /| ||_ _||_ _|| | |
 * |   /|   |\__ \ | | |   ||  \ | | | |  | | \   /
 * |_\_\|_|_|\___/ |_| |_|_||_\_\|_| |_|  |_|  |_| 
 *            https://rastakitty.com
 *        https://t.me/RastaKittyPortal
 *     https://twitter.com/rastakittytoken
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title INonfungiblePositionManager 
 * @dev Interface for interacting with the Nonfungible 
 * Position Manager contract in Uniswap V3.
 */
interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    function mint(MintParams calldata params) external payable returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);
}

contract RastaKitty is ERC20, Ownable {
    INonfungiblePositionManager posMan = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet
    address constant team = 0xaA63F6b94856A2f32333DfD116626efcCde74261;
    address constant marketing = 0x8006b1eef7884b21D4fE4De9Cb0EBB0cB56B5e4F;
    uint immutable uniswapSupply = 495_000_000 * 10 ** decimals();
    uint immutable marketingSupply = 2_500_000 * 10 ** decimals();
    uint immutable teamSupply = 2_500_000 * 10 ** decimals();

    uint24 constant fee = 3000;
    uint160 sqrtPriceX96;
    int24 minTick;
    int24 maxTick;
    address public pool;
    address token0;
    address token1;
    uint amount0Desired;
    uint amount1Desired;

    /**
     * @dev Constructor method initializes the ERC20 Token.
     * @notice Mints tokens to contract and marketing wallet.
     * Sets up initial liquidity pool but liquidity cannot 
     * be added in the same tx
     */
    constructor() ERC20("RastaKitty", "RAS") {
        _mint(address(this), uniswapSupply);
        _mint(marketing, marketingSupply);
        _mint(team, teamSupply);
        fixOrdering();
        pool = posMan.createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96);
    }

    /**
     * @dev Private function to establish the token pairs 
     * for liquidity pool based on lexicographical ordering. 
     * @notice Changing the price requires minTick/maxTick
     * to be adjusted as well.
     */
    function fixOrdering() private {
        if (address(this) < weth) {
            token0 = address(this);
            token1 = weth;
            sqrtPriceX96 = 56022299269611287018253980;
            amount0Desired = uniswapSupply;
            amount1Desired = 0;
            minTick = -145080;
            maxTick = 887220;
        } else {
            token0 = weth;
            token1 = address(this);
            sqrtPriceX96 = 112040883463736372645278684184779;
            amount0Desired = 0;
            amount1Desired = uniswapSupply;
            minTick = -887220;
            maxTick = 145080;
        }
    }

    /**
     * @dev Public onlyOwner function to provide liquidity to
     * the established Uniswap pool.
     */
    function addLiquidity() public onlyOwner {
        IERC20(address(this)).approve(address(posMan), uniswapSupply);
        posMan.mint(INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: minTick,
            tickUpper: maxTick,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp + 1200
        }));
    }
}