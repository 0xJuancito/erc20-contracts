// SPDX-License-Identifier: MIT

pragma solidity =0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

error ZeroAddress();
error ContractAddress();
error TradingAlreadyEnabled();
error NotEnoughTokens();


contract BLOX is IERC20, Ownable {
    mapping (address => uint) private _balances;
    mapping (address => mapping (address => uint)) private _allowances;
    mapping (address => bool) public allowList;

    //strings
    string private constant _name = 'BLOX';
    string private constant _symbol = 'BLOX';

    //uints
    uint private constant InitialSupply= 100_000_000 * 10**_decimals;
    uint8 private constant _decimals = 18;

    bool public tradingOpen = false;

    constructor () {
        _balances[msg.sender] = InitialSupply;
        allowList[msg.sender] = true;
    }

    /**
    * @notice Internal function to transfer tokens from one address to another.
     */
    function _transfer(
        address sender, 
        address recipient, 
        uint amount
    ) internal {
        if(sender == address(0)) revert ZeroAddress();
        if(recipient == address(0)) revert ZeroAddress();

        if(allowList[sender])
            _allowedTransfer(sender, recipient, amount);
        else {
            require(tradingOpen,"trading not yet enabled");
            _allowedTransfer(sender,recipient,amount);
        }
    }

    /**
    * @notice Transfer amount of tokens without fees.
    * @dev In feelessTransfer, there isn't limit as well.
    * @param sender The address of user to send tokens.
    * @param recipient The address of user to be recieveid tokens.
    * @param amount The token amount to transfer.
    */
    function _allowedTransfer(
        address sender, 
        address recipient, 
        uint amount
    ) internal {
        uint senderBalance = _balances[sender];
        require(senderBalance >= amount, "Transfer exceeds balance");
        _balances[sender]-=amount;
        _balances[recipient]+=amount;
        emit Transfer(sender,recipient,amount);
    }

    /**
    * @notice Get Burned tokens.
    * @dev This function is for get burned tokens.
    */
    function getBurnedTokens(
    ) public view returns(uint) {
        return _balances[address(0xdead)];
    }

    /**
    * @notice Get circulating supply.
    * @dev This function is for get circulating supply.
     */
    function getCirculatingSupply(
    ) public view returns(uint) {
        return InitialSupply-_balances[address(0xdead)];
    }


    /**
    * @notice Set to allowed trade early.
    * @dev This function is for set to allowed trade early.
    * @param account The address of user to be allowed early.
    * @param boolean The status of allowed.
    */
    function allowListChange(
        address account, 
        bool boolean
    ) external onlyOwner {
        if(account == address(0)) revert ZeroAddress();
        allowList[account]=boolean;
    }
    

    /**
    * @notice Used to start trading.
    * @dev This function is for used to start trading.
    */
    function SetupEnableTrading(
    ) external onlyOwner{
        if(tradingOpen) revert TradingAlreadyEnabled();
        tradingOpen = true;
    }

    receive() external payable {}
    function name() external pure override returns (string memory) {return _name;}
    function symbol() external pure override returns (string memory) {return _symbol;}
    function decimals() external pure override returns (uint8) {return _decimals;}
    function totalSupply() external pure override returns (uint) {return InitialSupply;}
    function balanceOf(address account) public view override returns (uint) {return _balances[account];}
    function isAllowed(address account) public view returns(bool) {return allowList[account];}
    
    function transfer(
        address recipient, 
        uint amount
    ) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    function allowance(
        address _owner, 
        address spender
    ) external view override returns (uint) {
        return _allowances[_owner][spender];
    }
    function approve(
        address spender, 
        uint amount
    ) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function _approve(
        address _owner, 
        address spender, 
        uint amount
    ) private {
        if(_owner == address(0)) revert ZeroAddress();
        if(spender == address(0)) revert ZeroAddress();
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }
    function transferFrom(
        address sender, 
        address recipient, 
        uint amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        uint currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "Transfer > allowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }
    function increaseAllowance(
        address spender, 
        uint addedValue
    ) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(
        address spender, 
        uint subtractedValue
    ) external returns (bool) {
        uint currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "<0 allowance");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    /**
    * @notice Used to remove excess ETH from contract
    * @dev This function is for used to remove excess ETH from contract.
    * @param amountPercentage The amount percentage to recover.
     */
    function emergencyETHrecovery(
        uint256 amountPercentage
    ) external onlyOwner {
        uint256 amountETH = address(this).balance;
        (bool sent,)=msg.sender.call{value:amountETH * amountPercentage / 100}("");
            sent=true;
    }
    
    /**
    * @notice Used to remove excess Tokens from contract
    * @dev This function is for used to remove excess Tokens from contract.
    * @param tokenAddress The token address to recover.
    * @param amountPercentage The amount percentage to recover.
     */
    function emergencyTokenrecovery(
        address tokenAddress, 
        uint256 amountPercentage
    ) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 tokenAmount = token.balanceOf(address(this));
        token.transfer(msg.sender, tokenAmount * amountPercentage / 100);
    }

}
