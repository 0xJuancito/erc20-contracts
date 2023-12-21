// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AnonWeb3Token is IERC20, IERC20Metadata, Context, Ownable {
    using SafeMath for uint256;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    uint256 private _maxPercentage;
    address private _teamOneWallet;
    address private _teamTwoWallet;
    address private _communityWallet;
    mapping(address => bool) private _routers;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    constructor() {
        _name = "Anon Web3 Token";
        _symbol = "AW3";
        _decimals = 18;
        _totalSupply = 1000000000 * 10**uint256(_decimals);
        _maxPercentage = 1;
        _teamOneWallet = 0xD727c5B0038baf8d7dBfDfC5341EEDaeE03BFB07;
        _teamTwoWallet = 0x57158CEb8DfAAc2082220CA00ec45BF1728EC14B;
        _communityWallet = 0x0D96891ef3cE7d26D2005231e83ECDE2269c9933;
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // Returns the token name
    function name() public view override returns (string memory) {
        return _name;
    }

    // Returns the token symbol 
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    // Returns the number of decimals used in the token 
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    // Returns the total supply of the token
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    // Returns the balance of a specific account
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    // Transfers tokens from the sender to the recipient
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    // Returns the amount of tokens that the spender is allowed to spend on behalf of the owner
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    // Approves the spender to spend a certain amount of tokens on behalf of the sender
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // Transfers tokens from one address to another with the sender's approval
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance")
        );
        return true;
    }

    // Increases the allowance granted to a spender
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    // Decreases the allowance granted to a spender
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero")
        );
        return true;
    }

    // Burns a specific amount of tokens, reducing the total supply
    function burn(uint256 amount) public returns (bool) {
        require(amount > 0, "ERC20: burn amount must be greater than zero");
        require(_balances[msg.sender] >= amount, "ERC20: burn amount exceeds balance");

        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    // Internal function for transferring tokens
    function _transfer(address sender, address recipient, uint256 amount) internal {
        // Verify balances
        uint256 senderBalance = _balances[sender];

        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        // Verify if it's a swap transaction
        bool isBuyTransaction = false;
        bool isSellTransaction = false;

        if (_routers[sender] && sender != owner()) {
            isBuyTransaction = true;
        }

        if (_routers[recipient] && sender != owner()) {
            isSellTransaction = true;
        }

        if (isBuyTransaction) {
            // Calculate the maximum amount allowed for the recipient based on _maxPercentage
            uint256 maxAmountAllowed = _totalSupply.mul(_maxPercentage).div(100);

            // Ensure the recipient's balance won't exceed the max allowed amount
            require(
                _balances[recipient].add(amount) <= maxAmountAllowed,
                "ERC20: recipient's balance would exceed the maximum allowed percentage"
            );
        }

        // Send tax if needed
        uint256 taxAmount = (isSellTransaction || isBuyTransaction) ? calculateTax(amount) : 0;

        if (taxAmount > 0) {
            uint256 teamShare = taxAmount.mul(2).div(5);
            uint256 marketingShare = taxAmount.mul(2).div(5);
            uint256 communityShare = taxAmount.sub(teamShare).sub(marketingShare);

            _balances[_teamOneWallet] = _balances[_teamOneWallet].add(teamShare);
            _balances[_teamTwoWallet] = _balances[_teamTwoWallet].add(marketingShare);
            _balances[_communityWallet] = _balances[_communityWallet].add(communityShare);

            emit Transfer(sender, _teamOneWallet, teamShare);
            emit Transfer(sender, _teamTwoWallet, marketingShare);
            emit Transfer(sender, _communityWallet, communityShare);
        }

        // Send transfer 
        uint256 transferAmount = amount.sub(taxAmount);
        
        _balances[sender] = senderBalance.sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(transferAmount);

        emit Transfer(sender, recipient, transferAmount);
    }

    // Internal function for approving spending
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // Calculate the tax amount (4% of the transaction amount)
    function calculateTax(uint256 amount) internal pure returns (uint256) {
        return amount.mul(4).div(100);
    }

    // Function to set the maximum percentage allowed in a single transaction (only callable by the owner)
    function setMaxPercentage(uint256 percentage) public onlyOwner {
        require(percentage <= 100, "Max percentage cannot exceed 100%");
        _maxPercentage = percentage;
    }

    // Function to add a router address (only callable by the owner)
    function addRouter(address router) public onlyOwner {
        require(router != address(0), "ERC20: router address cannot be zero");
        _routers[router] = true;
    }

    // Function to delete a router address (only callable by the owner)
    function deleteRouter(address router) public onlyOwner {
        require(router != address(0), "ERC20: router address cannot be zero");
        require(_routers[router], "ERC20: router address not found");
        _routers[router] = false;
    }

    // Function to get _routers
    function isRouter(address addr) public view returns (bool) {
        return _routers[addr];
    }

    // Function to change the _teamOneWallet address (only callable by the owner)
    function changeTeamOneWallet(address newWallet) public onlyOwner {
        require(newWallet != address(0), "ERC20: new wallet address cannot be zero");
        _teamOneWallet = newWallet;
    }

    // Function to change the _teamTwoWallet wallet address (only callable by the owner)
    function changeTeamTwoWallet(address newWallet) public onlyOwner {
        require(newWallet != address(0), "ERC20: new wallet address cannot be zero");
        _teamTwoWallet = newWallet;
    }

    // Function to change the _communityWallet address (only callable by the owner)
    function changeCommunityWallet(address newWallet) public onlyOwner {
        require(newWallet != address(0), "ERC20: new wallet address cannot be zero");
        _communityWallet = newWallet;
    }
}