// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract Arcstar is ERC20, Ownable {

    uint256 private initialSupply = 100_000_000_000 * (10 ** 18);

    uint8 public constant feeLimit = 5;
    uint8 public sellFee = 5;

    uint256 private constant denominator = 100;
    mapping(address => bool) public excludedList;
    mapping(address => bool) public sniperList;

    IUniswapV2Router02 public router;
    address public pairAddr;

    address public marketingWallet;
    address public presaleAddress;

    event SellFeeUpdated(uint8 fee);
    event SniperAdded(address[] addr);
    event SniperRemoved(address[] addr);
    event ExcludedAdded(address[] addr);
    event MarketingWalletUpdated(address addr);
    event PresaleAddressUpdated(address addr);

    constructor(address _routerAddr, address _marketingWallet) ERC20("Arcstar", "ARCSTAR")
    {
        require(_marketingWallet != address(0), "Invalid marketing address");
        excludedList[msg.sender] = true;
        excludedList[_marketingWallet] = true;
        excludedList[address(this)] = true;
        IUniswapV2Router02 _router = IUniswapV2Router02(_routerAddr);
        address _pairAddr = IUniswapV2Factory(_router.factory()).createPair(address(this), _router.WETH());
        router = _router;
        pairAddr = _pairAddr;
        marketingWallet = _marketingWallet;
        _mint(msg.sender, initialSupply);
    }

    receive() external payable {}

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override virtual {

        if (isExcluded(sender) || isExcluded(recipient)) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 baseUnit = amount / denominator;
        uint256 tax = 0;

        if (sniperList[sender] && (recipient == pairAddr || sender != pairAddr)) {
            tax = baseUnit * 9_9;
        } else if (recipient == pairAddr) {
            tax = baseUnit * uint256(sellFee);
        }

        if (tax > 0) {
            super._transfer(sender, marketingWallet, tax);
        }

        amount -= tax;

        super._transfer(sender, recipient, amount);
    }

    function setMarketingWallet(address _address) external onlyOwner {
        require(_address != address(0), "Invalid address");
        excludedList[_address] = true;
        marketingWallet = _address;
        emit MarketingWalletUpdated(_address);
    }

    function setPresaleAddress(address _address) external onlyOwner {
        require(_address != address(0), "Invalid address");
        excludedList[_address] = true;
        presaleAddress = _address;
        emit PresaleAddressUpdated(_address);
    }

    function setSellFee(uint8 _sellFee) public onlyOwner {
        require(_sellFee <= feeLimit, "ERC20: sell tax higher than tax limit");
        sellFee = _sellFee;
        emit SellFeeUpdated(_sellFee);
    }

    function setExcluded(address[] memory account) public onlyOwner {
        for (uint256 i = 0; i < account.length; i++) {
            if (account[i] != address(0) && !excludedList[account[i]]) {
                excludedList[account[i]] = true;
            }
        }
        emit ExcludedAdded(account);
    }

    function setSniper(address[] memory account) public onlyOwner {
        for (uint256 i = 0; i < account.length; i++) {
            if (account[i] != address(0) && !sniperList[account[i]]) {
                sniperList[account[i]] = true;
            }
        }
        emit SniperAdded(account);
    }

    function removeSniper(address[] memory account) public onlyOwner {
        for (uint256 i = 0; i < account.length; i++) {
            if (account[i] != address(0) && sniperList[account[i]]) {
                sniperList[account[i]] = false;
            }
        }
        emit SniperRemoved(account);
    }

    function isExcluded(address account) public view returns (bool) {
        return excludedList[account];
    }

    function isSniper(address account) public view returns (bool) {
        return sniperList[account];
    }
}