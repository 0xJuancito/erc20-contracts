// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "src/interfaces/IUniswapV2Router02.sol";
import "src/interfaces/IUniswapV2Factory.sol";
import "src/interfaces/IUniswapV2Pair.sol";

/*
    @title GARBAGE token contract with bot-sniping protection
    @dev Anti sniping realised by blocking transfer for several blocks after providing liquidity
    @dev There is hold limit functionality here, it should stops single wallet from holding more than 1% of liquidity pool size
    @dev Hold limit does not apply to this contract, owner and uniswap pair
**/
contract GarbageToken is ERC20, Ownable {
    uint256 private constant antiBotDelay = 5;// for how many blocks after providing liquidity transfers should be blocked
    uint256 public immutable minHoldLimit;// holding cap when holding limit is enabled

    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);// WETH token address
    IUniswapV2Router02 public constant uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);// UniswapV2Router address

    uint256 public antiBotDelayStartBlock;// block from which bot protection delay is calculated
    uint256 public holdLimit;// holding cap when holding limit is enabled
    bool public isHoldLimitActive;// displays if holding limit is enabled
    IUniswapV2Pair public uniswapPair;// address of Uniswap pair

    event HoldLimitEnabled();
    event HoldLimitDisabled();
    event HoldLimitValueSet(uint256 newValue);
    event PairCreated(address pairAddress);
    event LiquidityProvided(uint256 tokenAmount, uint256 wethAmount, uint256 block, uint256 timestamp);

    error PairAlreadyCreated();
    error PairNotCreated();
    error TransfersBlocked();
    error HoldLimitation();
    error TooLowHoldLimit();

    /*
        @notice Sets up contract while deploying
        @param _initialSupply: How manu tokens should be minted
        @param _owner: Address that will be defined as owner
    **/
    constructor(uint256 _initialSupply, address _owner) ERC20("$GARBAGE", "$GARBAGE") Ownable(_owner) {
        uint256 initialSupply = _initialSupply * 10 ** decimals();
        _mint(_owner, initialSupply);
        holdLimit = initialSupply / 200;
        minHoldLimit = holdLimit / 100;
    }

    /*
        @notice Sets hold limit
        @param _newHoldLimit: new hold limit amount
        @dev While liquidity can be provided externally there is an ability to correct hold limit
    **/
    function setHoldLimit(uint256 _newHoldLimit) external onlyOwner {
        if (_newHoldLimit < minHoldLimit) revert TooLowHoldLimit();
        holdLimit = _newHoldLimit;
        emit HoldLimitValueSet(_newHoldLimit);
    }

    // @notice enables hold limit
    function turnHoldLimitOn() external onlyOwner {
        isHoldLimitActive = true;
        emit HoldLimitEnabled();
    }

    // @notice Disables hold limit
    function turnHoldLimitOff() external onlyOwner {
        isHoldLimitActive = false;
        emit HoldLimitDisabled();
    }

    // @notice Creates GARBAGE/WETH pair on Uniswap
    function createPair() external onlyOwner {
        if (address(uniswapPair) != address(0)) revert PairAlreadyCreated();
        uniswapPair = IUniswapV2Pair(
            IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), address(WETH))
        );
        emit PairCreated(address(uniswapPair));
    }

    /*
        @notice Provides liquidity to Uniswap
        @param _shouldBlock: marks if anti-snipers protection and hold limit should be enabled after providing liquidity
        @dev all contracts balances in GARBAGE and WETH will be provided as liquidity
        @dev liquidity tokens will be sent to owner
    **/
    function provideLiquidity(bool shouldBlock) external onlyOwner {
        if (address(uniswapPair) == address(0)) revert PairNotCreated();
        uint256 tokenToList = balanceOf(address(this));
        uint256 wethToList = WETH.balanceOf(address(this));

        _approve(address(this), address(uniswapV2Router), tokenToList);
        WETH.approve(address(uniswapV2Router), wethToList);

        (uint256 tokenProvided, uint256 wethProvided,) = uniswapV2Router.addLiquidity(
            address(this),
            address(WETH),
            tokenToList,
            wethToList,
            0,
            0,
            owner(),
            block.timestamp);

        emit LiquidityProvided(tokenProvided, wethProvided, block.number, block.timestamp);

        if (shouldBlock) {
            antiBotDelayStartBlock = block.number;
            isHoldLimitActive = true;

            emit HoldLimitEnabled();
        }
    }

    // @notice Transfers ERC20 tokens to owner to avoid tokens stuck on contract
    // @param _token: address of token that should be sent
    // @param _amount: amount of tokens to send
    function rescueERC20(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }

    // @notice Modified ERC20 _update function
    function _update(address from, address to, uint256 value) internal override {
        // checking if enough blocks were passed after providing liquidity
        if (antiBotDelayStartBlock != 0
            && block.number <= antiBotDelayStartBlock + antiBotDelay) revert TransfersBlocked();

        // checking that resulting wallet value will fit the limit if it is enabled
        if (isHoldLimitActive
            && balanceOf(to) + value > holdLimit
            && to != address(uniswapPair)
            && to != owner()
            && to != address(this)
        ) {
            revert HoldLimitation();
        }

        // original update function
        super._update(from, to, value);
    }
}
