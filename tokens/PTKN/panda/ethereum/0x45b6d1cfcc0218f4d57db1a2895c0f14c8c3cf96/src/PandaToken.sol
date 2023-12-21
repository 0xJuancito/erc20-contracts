// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

interface IUniswapRouterV2 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function WETH() external pure returns (address);
}

uint256 constant TOTAL_SUPPLY = 888_888_888 ether;
address constant UNISWAP_V2_ROUTER = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
uint256 constant RESERVED_FOR_TREASURY = TOTAL_SUPPLY * uint256(888) / uint256(10000); //8.88%
uint256 constant RESERVED_FOR_LIQUIDITY = TOTAL_SUPPLY - RESERVED_FOR_TREASURY;
address constant UNISWAP_V2_FACTORY = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

contract PandaToken is ERC20, ERC20Permit, Ownable {
    error AlreadyInitialized();
    error MaxHoldingAmountExceeded();

    address private constant TREASURY = address(0xA9f8fD4e30Bcd49ED4a255E69f5565482Be0d279);
    uint256 public constant MAX_HOLDING_AMOUNT_PER_WALLET = TOTAL_SUPPLY * uint256(2) / uint256(100); //2%
    address public immutable uniswapV2Pair;
    address public liquidityProvider;
    bool public limitsOn = true;

    constructor(address _owner) payable ERC20("Panda", "PTKN") ERC20Permit("Panda") Ownable(_owner) {
        uniswapV2Pair = pairFor(UNISWAP_V2_FACTORY, address(this), IUniswapRouterV2(UNISWAP_V2_ROUTER).WETH());
    }

    function init() external payable onlyOwner {
        if (liquidityProvider != address(0)) _revert(AlreadyInitialized.selector);
        _mint(TREASURY, RESERVED_FOR_TREASURY);
        LiquidityProvider _liquidityProvider = new LiquidityProvider();
        liquidityProvider = address(_liquidityProvider);
        _mint(address(liquidityProvider), RESERVED_FOR_LIQUIDITY);
        _liquidityProvider.setLP{value: msg.value}();
    }

    function _update(address from, address to, uint256 value) internal override(ERC20) {
        uint256 _value = value;
        if (limitsOn) {
            if (from == uniswapV2Pair) {
                uint256 balanceTo = balanceOf(to);
                if (balanceTo + value > MAX_HOLDING_AMOUNT_PER_WALLET) {
                    _revert(MaxHoldingAmountExceeded.selector);
                }

                uint256 tax = _computeTax(value);
                _value = value - tax;

                super._update(from, TREASURY, tax);
            }
            if (to == uniswapV2Pair) {
                if (from != liquidityProvider) {
                    uint256 tax = _computeTax(value);
                    _value = value - tax;
                    super._update(from, TREASURY, tax);
                }
            }
        }
        super._update(from, to, _value);
    }

    function renounceOwnership() public override onlyOwner {
        limitsOn = false;
        super.renounceOwnership();
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                        )
                    )
                )
            )
        );
    }

    function _computeTax(uint256 amount) internal pure returns (uint256) {
        return amount * 3 / 100; //3% tax
    }

    function withdrawERC20(address _token, uint256 _amount) external {
        if (_token == address(0)) {
            (bool os,) = payable(TREASURY).call{value: _amount}("");
            require(os, "withdrawERC20: ETH transfer failed");
        } else {
            ERC20(_token).transfer(TREASURY, _amount);
        }
    }

    function _revert(bytes4 selector) private pure {
        assembly {
            mstore(0x0, selector)
            revert(0x0, 0x4)
        }
    }
}

contract LiquidityProvider {
    function setLP() external payable {
        PandaToken token = PandaToken(msg.sender);
        token.approve(UNISWAP_V2_ROUTER, type(uint256).max);
        // {RESERVED_FOR_LIQUIDITY} is the amount of tokens that will be added to the pool
        // along with all the msg.value
        IUniswapRouterV2(UNISWAP_V2_ROUTER).addLiquidityETH{value: msg.value}(
            address(token), RESERVED_FOR_LIQUIDITY, RESERVED_FOR_LIQUIDITY, msg.value, address(0), block.timestamp
        );
    }
}
