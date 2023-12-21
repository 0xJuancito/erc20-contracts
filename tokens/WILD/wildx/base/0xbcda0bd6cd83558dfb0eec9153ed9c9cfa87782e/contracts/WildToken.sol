// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import "./pancakeSwap/interfaces/IPancakeFactory.sol";
import "./pancakeSwap/interfaces/IPancakeRouter02.sol";

contract WildToken is ERC20, Ownable, ERC20Permit, ERC20Votes {
    mapping(address => bool) public isPair;
    uint public sellTax;

    event IsPairSet(address indexed pairAddress, bool isPair);
    event DevAddressUpdated(address indexed newDevAddress);
    event SellTaxUpdated(uint newSellTax);

    uint256 public startTime;

    uint256 public firstTaxRate = 1200;
    uint256 public secondTaxRate = 1000;
    uint256 public thirdTaxRate = 800;
    uint256 public staticTaxRate = 600;
    uint256 public duration = 1 days;
    uint256 public constant MAX_TAX_RATE = 2000;

    constructor(
        address _USDC,
        address _routerAddress
    ) ERC20("wildbase.farm", "WILDx") ERC20Permit("WILDx") {
        IPancakeRouter02 uniswapV2Router = IPancakeRouter02(_routerAddress);
        address WETH = uniswapV2Router.WETH();
        // Create a uniswap pair for this new token
        address pair = IPancakeFactory(uniswapV2Router.factory()).createPair(address(this), WETH);
        address pairUsdc = IPancakeFactory(uniswapV2Router.factory()).createPair(address(this), _USDC);
        isPair[pair] = true;
        isPair[pairUsdc] = true;
        startTime = block.timestamp;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }
    function getCurrentTaxRate() public view returns  (uint256) {
        return _getStaticTaxRate();
    }

    function _getStaticTaxRate() private view returns (uint256) {
        if (block.timestamp - startTime > 0 && block.timestamp - startTime <= duration) {
            return firstTaxRate;
        } else if (block.timestamp - startTime > duration && block.timestamp - startTime <= 2 * duration) {
            return secondTaxRate;
        } else if (block.timestamp - startTime > 2 * duration && block.timestamp - startTime <= 3 * duration) {
            return thirdTaxRate;
        } else {
            return staticTaxRate;
        }
    }
    // The following functions are overrides required by Solidity.

    function _transfer(address _from, address _to, uint256 _amount) internal override {
        if (isPair[_to]) {
            uint taxAmount = (_amount * getCurrentTaxRate()) / 10000;
            _burn(_from, taxAmount);
            super._transfer(_from, _to, _amount - taxAmount);
        } else {
            super._transfer(_from, _to, _amount);
        }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
