// SPDX-License-Identifier: UNLICENSED



pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./pancakeSwap/interfaces/IPancakeFactory.sol";
import "./pancakeSwap/interfaces/IPancakeRouter02.sol";

contract BWildToken is ERC20, Ownable, ERC20Permit, ERC20Votes {
    using SafeMath for uint256;

    address public admin;
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public startTime;
    uint256 public totalBurned;

    uint256 public staticTaxRate = 800;
    uint256 public MAX_TAX_RATE = 1800;
    uint256 public constant duration = 1 days;

    mapping(address => bool) public isPair;
    mapping(address => bool) public proxylist;

    constructor(address _routerAddress) ERC20("BWiLD Token", "BWiLD") ERC20Permit("BWiLD") {
        admin = msg.sender;
        IPancakeRouter02 uniswapV2Router = IPancakeRouter02(_routerAddress);
        address WETH = uniswapV2Router.WETH();
        // Create a uniswap pair for this new token
        address pair = IPancakeFactory(uniswapV2Router.factory()).createPair(address(this), WETH);
        isPair[pair] = true;
        startTime = block.timestamp;
        admin = msg.sender;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function getCurrentTaxRate() public view returns (uint256) {
        for (uint256 i = 0; i < 30; i++) {
            if (block.timestamp <= startTime + duration * i) {
                uint256 tax = MAX_TAX_RATE - (i - 1) * 100;
                return tax < staticTaxRate ? staticTaxRate : tax;
            }
        }
        return staticTaxRate;
    }

    function _transfer(address _from, address _to, uint256 _amount) internal override {
        if (isPair[_to] && !proxylist[_from]) {
            uint256 taxAmount = (_amount * getCurrentTaxRate()) / 10000;
            _burn(_from, taxAmount);
            totalBurned += taxAmount;
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
        super._transfer(account, deadAddress, amount);
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function setProxy(address _proxy) public {
        require(msg.sender == admin, "You are not the admin");
        require(isContract(_proxy), "only contracts can be whitelisted");
        proxylist[_proxy] = true;
    }

    function setPair(address _pair) public {
        require(msg.sender == admin, "You are not the admin");
        require(isContract(_pair), "only contracts can be whitelisted");
        isPair[_pair] = true;
    }

    function setMaxTaxRate(uint256 _newMaxRate) external onlyOwner {
        require(_newMaxRate > staticTaxRate, "Invalid Max Tax Rate");
        MAX_TAX_RATE = _newMaxRate;
    }

    function setStaticTaxRate(uint256 _newStaticRate) external onlyOwner {
        require(_newStaticRate > 0, "Invalid Static Tax Rate");
        staticTaxRate = _newStaticRate;
    }
}
