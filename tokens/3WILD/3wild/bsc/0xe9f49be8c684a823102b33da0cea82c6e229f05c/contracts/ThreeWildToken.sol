// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./pancakeSwap/interfaces/IPancakeFactory.sol";
import "./pancakeSwap/interfaces/IPancakeRouter02.sol";

contract ThreeWildToken is ERC20, Ownable, ERC20Permit, ERC20Votes {
    using SafeMath for uint256;

    mapping(address => bool) public isPair;
    uint public sellTax;

    event IsPairSet(address indexed pairAddress, bool isPair);
    event DevAddressUpdated(address indexed newDevAddress);
    event SellTaxUpdated(uint newSellTax);

    address public admin;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    uint256 public startTime;
    uint256 public totalBurned;

    uint256 public staticTaxRate = 800;
    uint256 public duration = 1 days; // 1 days;
    uint256 public constant MAX_TAX_RATE = 1800;
    mapping(address => bool) public proxylist;

    modifier onlyAdmin() {
        require(admin == _msgSender(), "You are not the admin");
        _;
    }

    constructor(address _routerAddress) ERC20("3WiLD.farm", "3WiLD") ERC20Permit("3WiLD") {
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
        return _getStaticTaxRate();
    }

    function _getStaticTaxRate() private view returns (uint256) {
        for (uint256 i = 0; i < 11; i++) {
            if (block.timestamp <= startTime.add(duration.mul(i))) {
                uint256 tax = MAX_TAX_RATE.sub((i.sub(1)).mul(100));
                if (tax < staticTaxRate) {
                    return staticTaxRate;
                } else {
                    return tax;
                }
            }
        }
        return staticTaxRate;
    }

    // The following functions are overrides required by Solidity.

    function _transfer(address _from, address _to, uint256 _amount) internal override {
        if (isPair[_to] && proxylist[_from] == false) {
            uint taxAmount = (_amount * getCurrentTaxRate()) / 10000;
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
        _transfer(account, deadAddress, amount);
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    // set proxylist
    function setProxy(address _proxy) public onlyAdmin {
        require(isContract(_proxy) == true, "only contracts can be whitelisted");
        proxylist[_proxy] = true;
    }
}
