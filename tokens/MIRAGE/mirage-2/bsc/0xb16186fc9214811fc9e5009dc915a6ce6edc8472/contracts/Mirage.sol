// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract Mirage is ERC20, Ownable {

    uint256 private initialSupply = 100_000_000 * (10 ** 18);

    uint8 public constant feeLimit = 5;
    uint8 public developmentFee = 0;
    uint8 public marketingFee = 0;

    address public developmentWallet;
    address public marketingWallet;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping(address => uint8) public excluded;

    uint8 private constant EXCLUDE_MARKETING_FEE = 0;
    uint8 private constant EXCLUDE_DEVELOPMENT_FEE = 1;
    uint8 private constant EXCLUDE_ANY_FEE = 2;

    constructor(address _uniswapAddr, address _developmentWallet, address _marketingWallet) ERC20("Mirage", "MIRAGE")
    {
        require(_uniswapAddr != address(0), "Router address cannot be empty");
        excluded[msg.sender] = EXCLUDE_ANY_FEE;
        excluded[address(this)] = EXCLUDE_ANY_FEE;
        excluded[_uniswapAddr] = EXCLUDE_ANY_FEE;
        excluded[_developmentWallet] = EXCLUDE_ANY_FEE;
        excluded[_marketingWallet] = EXCLUDE_ANY_FEE;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_uniswapAddr);
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
        developmentWallet = _developmentWallet;
        marketingWallet = _marketingWallet;

        _mint(msg.sender, initialSupply);
    }

    function setDevelopmentWallet(address _wallet) public onlyOwner {
        developmentWallet = _wallet;
        excluded[_wallet] = EXCLUDE_ANY_FEE;
    }

    function setMarketingWallet(address _wallet) public onlyOwner {
        marketingWallet = _wallet;
        excluded[_wallet] = EXCLUDE_ANY_FEE;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override virtual {

        if (excluded[sender] == EXCLUDE_ANY_FEE || excluded[recipient] == EXCLUDE_ANY_FEE) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 baseUnit = amount / 100;
        uint256 tax = 0;

        if ((excluded[sender] == EXCLUDE_DEVELOPMENT_FEE || excluded[recipient] == EXCLUDE_DEVELOPMENT_FEE) && (recipient == uniswapV2Pair || sender != uniswapV2Pair)) {
            tax = baseUnit * uint256(marketingFee);
            super._transfer(sender, marketingWallet, tax);
        } else if (recipient == uniswapV2Pair) {
            tax = baseUnit * uint256(developmentFee);
            super._transfer(sender, developmentWallet, tax);
        }

        amount -= tax;

        super._transfer(sender, recipient, amount);
    }

    function setFees(uint8 _development, uint8 _marketing) public onlyOwner {
        require(_development <= feeLimit && _marketing <= feeLimit, "ERC20: Development or marketing fee value higher than fee limit");
        developmentFee = _development;
        marketingFee = _marketing;
    }

    function setExcluded(address[] memory addresses, uint8 includeOrExclude) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            excluded[addresses[i]] = includeOrExclude;
        }
    }

    function rescueBNB() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}