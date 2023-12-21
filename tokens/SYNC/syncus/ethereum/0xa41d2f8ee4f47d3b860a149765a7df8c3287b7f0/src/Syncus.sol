// SPDX-License-Identifier: AGPL-3.0-or-later
pragma abicoder v2;
pragma solidity 0.7.5;
import "./lib/EnumerableSet.sol";
import "./lib/IERC2612Permit.sol";
import "./lib/IERC20.sol";
import "./ERC20Permit.sol";
import "./VaultOwned.sol";
import "./lib/IWETH.sol";
import "./lib/IUniswapV2Router.sol";
import "./lib/IUniswapV2Factory.sol";

contract Syncus is ERC20Permit, VaultOwned {
    using SafeMath for uint256;

    IUniswapV2Router public router =
        IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public uniswapV2Pair;

    address private treasury;

    uint256 public buyTax = 5;

    uint256 public sellTax = 15;

    mapping(address => bool) private _isExcludedFromTaxes;

    mapping(address => bool) public automatedMarketMakerPairs;

    receive() external payable {}

    constructor() ERC20("Syncus", "SYNC", 9) {
        _mint(msg.sender, 4_000_000_000 * 1e9);

        uniswapV2Pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        treasury = msg.sender;

        excludeFromTaxes(owner(), true);
        excludeFromTaxes(address(this), true);
        excludeFromTaxes(address(0xdead), true);
    }

    function mint(address account_, uint256 amount_) external onlyVault {
        _mint(account_, amount_);
    }

    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account_, uint256 amount_) public virtual {
        _burnFrom(account_, amount_);
    }

    function _burnFrom(address account_, uint256 amount_) public virtual {
        uint256 decreasedAllowance_ = allowance(account_, msg.sender).sub(
            amount_,
            "ERC20: burn amount exceeds allowance"
        );

        _approve(account_, msg.sender, decreasedAllowance_);
        _burn(account_, amount_);
    }

    function excludeFromTaxes(address account, bool excluded) public onlyOwner {
        _isExcludedFromTaxes[account] = excluded;
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
    }

    function updateBuyTax(uint256 _buyTax) external onlyOwner {
        require(_buyTax <= 100, "Cannot set tax higher than 100%");
        buyTax = _buyTax;
    }

    function updateSellTax(uint256 _sellTax) external onlyOwner {
        require(_sellTax <= 100, "Cannot set tax higher than 100%");
        sellTax = _sellTax;
    }

    function updateTaxes(uint256 _buyTax, uint256 _sellTax) external onlyOwner {
        require(
            _sellTax <= 100 && _buyTax <= 100,
            "Cannot set taxes higher than 100%"
        );
        buyTax = _buyTax;
        sellTax = _sellTax;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        bool takeTax = true;

        if (_isExcludedFromTaxes[from] || _isExcludedFromTaxes[to]) {
            takeTax = false;
        }
        uint256 taxes = 0;
        if (takeTax) {
            if (automatedMarketMakerPairs[to] && sellTax > 0) {
                taxes = amount.mul(sellTax).div(100);
            } else if (automatedMarketMakerPairs[from] && buyTax > 0) {
                taxes = amount.mul(buyTax).div(100);
            }
            if (taxes > 0) {
                super._transfer(from, treasury, taxes);
            }

            amount -= taxes;
        }

        super._transfer(from, to, amount);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }
}
