// SPDX-License-Identifier: MIT
// D-Drops official token contract
// Date: 8-7-2023
pragma solidity ^0.8.3;

import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Pair.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Ownable.sol";

contract Dop is Ownable, IERC20 {
    using SafeMath for uint256;

    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isBlacklisted;

    bool private _canBurn = false;
    bool private _blacklistMode = true;

    string private constant _name = "DDrops";
    string private constant _symbol = "DOP";
    uint8 private constant _decimals = 18;
    uint private constant _totalSupply = 3375 * 10 ** 5 * 10 ** _decimals;

    receive() external payable {}

    uint private _buyContributionFee;
    uint private _sellContributionFee;
    uint private _previousBuyContributionFee;
    uint private _previousSellContributionFee;

    uint private _maxTrxAmount = _totalSupply;

    address private _treasureWalletAddress;
    address private _developementWalletAddress;

    address public uniswapV2RouterAddress;
    address[] public uniswapV2Pairs;
    mapping(address => bool) public isUniswapV2Pair;

    bool private _lock;

    function isBlackListMode() public view returns (bool) {
        return _blacklistMode;
    }

    function getTreasureWallet() public view returns (address) {
        return _treasureWalletAddress;
    }

    function getBuyContributionFee() public view returns (uint) {
        return _buyContributionFee;
    }

    function getSellContributionFee() public view returns (uint) {
        return _sellContributionFee;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function getMaxTrxAmount() public view returns (uint) {
        return _maxTrxAmount;
    }

    /***** onlyOwner functions to change private parameters *****/

    //Enable burn through dxSale
    function setCanBurn(bool _value) external onlyOwner {
        _canBurn = _value;
    }

    //Enable blacklisting
    function setBlacklistMode(bool _value) external onlyOwner {
        _blacklistMode = _value;
    }

    //Add or remove one or more addresses from the black list, make sure to send enough gas
    function manage_blacklist(
        address[] calldata _addresses,
        bool _value
    ) external onlyOwner {
        for (uint256 i; i < _addresses.length; ++i) {
            _isBlacklisted[_addresses[i]] = _value;
        }
    }

    // Set uniswapV2RouterAddress
    function setRouterAddress(address _newRouterAddress) external onlyOwner {
        uniswapV2RouterAddress = _newRouterAddress;
    }

    function createUniswapV2Pair(
        address _WETH
    ) external onlyOwner returns (address) {
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(
            uniswapV2RouterAddress
        );
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), _WETH);

        uniswapV2Pairs.push(_uniswapV2Pair);
        isUniswapV2Pair[address(_uniswapV2Pair)] = true;
        return _uniswapV2Pair;
    }

    // Set total amount of tokens that can be traded per transaction
    function setMaxTrxAmount(
        uint _newMaxTrxAmount
    ) external onlyOwner returns (bool) {
        _maxTrxAmount = _newMaxTrxAmount;
        return true;
    }

    // Set the amount of BUY contribution fee, limited to max 15%
    function setBuyContributionFee(
        uint _newBuyContributionFee
    ) external onlyOwner returns (bool) {
        require(_newBuyContributionFee <= 50);
        _buyContributionFee = _newBuyContributionFee;
        return true;
    }

    // Set the amount of SELL contribution fee, limited to max 20%
    function setSellContributionFee(
        uint _newSellContributionFee
    ) external onlyOwner returns (bool) {
        require(_newSellContributionFee <= 50);
        _sellContributionFee = _newSellContributionFee;
        return true;
    }

    function setDevelopementWallet(
        address _newDevelopementWallet
    ) external onlyOwner returns (bool) {
        _developementWalletAddress = _newDevelopementWallet;
        return true;
    }

    function setTreasureWallet(
        address _newTreasureWallet
    ) external onlyOwner returns (bool) {
        _treasureWalletAddress = _newTreasureWallet;
        return true;
    }

    function excludeFromFee(address _account) external onlyOwner {
        _isExcludedFromFee[_account] = true;
    }

    function includeInFee(address _account) external onlyOwner {
        _isExcludedFromFee[_account] = false;
    }

    /******************* End of onlyOwner functions*********************/
    modifier noReEntry() {
        _lock = true;
        _;
        _lock = false;
    }

    constructor() {
        _maxTrxAmount = 10000000 * 10 ** _decimals;
        _balances[_msgSender()] = 3375 * 10 ** 5 * 10 ** _decimals;

        _buyContributionFee = 5; //this is also the normal transaction fee
        _sellContributionFee = 5;

        _treasureWalletAddress = 0xD6EB8Eeb7403714E1f2074BAF9EBDBBBEfcB9400;
        _developementWalletAddress = 0x1518b9Dfe74f46443b1cAEb3aeF96903b015c005;
        uniswapV2RouterAddress = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;

        //exclude owner,and this contract form fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[uniswapV2RouterAddress] = true;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function burn(uint _amount) public {
        require(_amount > 0, "Burn amount must be greater than zero");
        require(
            _amount <= _balances[msg.sender],
            "Not enough fonds to complete the transaction"
        );
        _balances[msg.sender] = _balances[msg.sender].sub(_amount);
        _balances[0x000000000000000000000000000000000000dEaD] = _balances[
            0x000000000000000000000000000000000000dEaD
        ].add(_amount);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _transfer(_msgSender(), _recipient, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _transfer(_sender, _recipient, _amount);
        _approve(
            _sender,
            _msgSender(),
            _allowances[_sender][_msgSender()].sub(
                _amount,
                "ERC20: Transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _transfer(address _from, address _to, uint _amount) internal {
        require(_from != address(0), "ERC20: transfer from the zero address");
        if (_canBurn == false) {
            require(_to != address(0), "ERC20: transfer to the zero address");
        }
        require(_amount > 0, "Transfer amount must be greater than zero");
        require(_amount <= _balances[_from], "Insufficient funds");

        if (_from != owner() && _to != owner()) {
            require(
                _amount <= _maxTrxAmount,
                "Transfer amount exceeds the maxTrxAmount."
            );
        }

        // Check for blacklist
        if (_blacklistMode) {
            require(
                !_isBlacklisted[_from] && !_isBlacklisted[_to],
                "Transaction between these two accounts is blacklisted"
            );
        }
        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[_from] || _isExcludedFromFee[_to]) {
            takeFee = false;
        }
        //Here we initiate the transfer fuction
        _transferToken(_from, _to, _amount, takeFee);
    }

    function _transferToken(
        address _from,
        address _to,
        uint _amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        uint _takeContribution;
        //Code Below: decide if its a buy or sell order and adjust tax accoirdingly
        if (_isIncludedInV2Pairs(_to)) {
            _takeContribution = _calculateAbsoluteSellContributionFee(_amount);
        } else if (_isIncludedInV2Pairs(_from)) {
            _takeContribution = _calculateAbsoluteBuyContributionFee(_amount);
        } else {
            _takeContribution = 0;
        }
        uint trAmountToRecipient = _amount.sub(_takeContribution);
        uint trAmountToContract = _takeContribution;

        _balances[_from] = _balances[_from].sub(_amount);
        _balances[_to] = _balances[_to].add(trAmountToRecipient);
        _balances[address(this)] = _balances[address(this)].add(
            trAmountToContract
        );

        if (!takeFee) {
            restoreAllFee();
        }

        emit Transfer(_from, _to, _amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function payOut() external {
        uint256 contractBalance = balanceOf(address(this));
        uint256 _developementWalletAmount = contractBalance.mul(50).div(100);
        uint256 _treasureWalletAmount = contractBalance -
            _developementWalletAmount;
        _transfer(
            address(this),
            _developementWalletAddress,
            _developementWalletAmount
        );
        _transfer(address(this), _treasureWalletAddress, _treasureWalletAmount);
    }

    function removeAllFee() internal {
        if ((_buyContributionFee == 0) && (_sellContributionFee == 0)) return;

        _previousBuyContributionFee = _buyContributionFee;
        _previousSellContributionFee = _sellContributionFee;

        _buyContributionFee = _sellContributionFee = 0;
    }

    function restoreAllFee() internal {
        _buyContributionFee = _previousBuyContributionFee;
        _sellContributionFee = _previousSellContributionFee;
    }

    //Note buyContributionFee is the same as reqular transaction fee
    function _calculateAbsoluteBuyContributionFee(
        uint amount
    ) internal view returns (uint) {
        return amount.mul(_buyContributionFee).div(10 ** 2);
    }

    function _calculateAbsoluteSellContributionFee(
        uint amount
    ) internal view returns (uint) {
        return amount.mul(_sellContributionFee).div(10 ** 2);
    }

    function _isIncludedInV2Pairs(
        address candidate
    ) internal view returns (bool) {
        return isUniswapV2Pair[candidate];
    }
}
