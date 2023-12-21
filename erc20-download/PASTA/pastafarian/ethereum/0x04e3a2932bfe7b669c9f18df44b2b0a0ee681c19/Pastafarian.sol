//Pastafarian Coin
/*
https://t.me/PastafarianCoin
https://twitter.com/PastafarianCoin
https://www.instagram.com/pastafariancoin/
https://www.tiktok.com/@pastafariancoin
https://www.youtube.com/@PastafarianCoin
https://www.facebook.com/PastafarianCoin/
https://www.reddit.com/r/PastafarianCoin/
https://www.threads.net/@pastafariancoin
https://medium.com/@pastafariancoin
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

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
interface ISigner{
    function signed(address signer) external returns(bool signed) ;
}
interface IUniswapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapRouter {
   
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}





pragma solidity ^0.8.18;
contract Pastafarian is IERC20, Ownable
{
  
    mapping (address => uint) private _balances;
    mapping (address => mapping (address => uint)) private _allowances;
    mapping(address => bool)  _excludedFromFees;

    string public constant name = 'Pastafarian';
    string public constant symbol = 'PASTA';
    uint8 public constant decimals = 18;
    uint public constant totalSupply= 420420420420 * 10**decimals;


    address private constant UniswapRouter=0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D ;
    //MainNet
    address private constant USDAddress=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant USDPair=0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    ISigner whitelist=ISigner(0x29Bd5718F5Af4E01889c02c11A6478EA2D4cf633);
    //Testnet
    //address private constant USDAddress=0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    //address private USDPair=0x647595535c370F6092C6daE9D05a7Ce9A8819F37;
    //ISigner whitelist=ISigner(0x264c66A00bd05Daf39E6F6b9Ed9dAdcD8a05AD51);

    address private _UniswapPairAddress; 
    IUniswapRouter private  _UniswapRouter;
    
    
    address public marketingWallet;
    address public liquidityWallet;
    //Only marketingWallet can change marketingWallet
    function ChangeMarketingWallet(address newWallet) public{
        require(msg.sender==marketingWallet);
        marketingWallet=newWallet;
    }
    function ChangeLiquidityWallet(address newWallet) public onlyOwner{
        liquidityWallet=newWallet;
    }
    function ChangeSigner(address newWallet) public onlyOwner{
        whitelist=ISigner(newWallet);
    }



    constructor () {
        
        _balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
        _UniswapRouter = IUniswapRouter(UniswapRouter);
        _UniswapPairAddress = IUniswapFactory(_UniswapRouter.factory()).createPair(address(this), _UniswapRouter.WETH());
        marketingWallet=msg.sender;
        _excludedFromFees[msg.sender]=true;
        _excludedFromFees[UniswapRouter]=true;
        _excludedFromFees[address(this)]=true;
    }
  
    function _transfer(address sender, address recipient, uint amount) private{

        if(_excludedFromFees[sender] || _excludedFromFees[recipient])
            _feelessTransfer(sender, recipient, amount);
        else{ 
            require(block.timestamp>=LaunchTimestamp,"trading not yet enabled");
            _taxedTransfer(sender,recipient,amount);                  
        }
    }
    function _taxedTransfer(address sender, address recipient, uint amount) private{
        uint senderBalance = _balances[sender];
        require(senderBalance >= amount, "Transfer exceeds balance");

        bool isBuy=_UniswapPairAddress==sender;
        
        if(isBuy){
            require((_balances[recipient]+amount)<=(totalSupply*2/100),"Max Wallet");
            if(block.timestamp<LaunchTimestamp+195 minutes)
                    require(whitelist.signed(recipient),"Not whitelisted");

        }
        

        if((sender!=_UniswapPairAddress)&&(!_isSwappingContractModifier))
            _swapContractToken();

        unchecked{
            uint contractToken= amount/100;
            uint taxedAmount=amount-contractToken;
            _balances[sender]-=amount;
            _balances[address(this)] += contractToken;
            _balances[recipient]+=taxedAmount;
        }

        
        emit Transfer(sender,recipient,amount);
    }

    function _feelessTransfer(address sender, address recipient, uint amount) private{
        uint senderBalance = _balances[sender];
        require(senderBalance >= amount, "Transfer exceeds balance");
        unchecked
        {
            _balances[sender]-=amount;
            _balances[recipient]+=amount; 
        }
     
        emit Transfer(sender,recipient,amount);
    }

    bool private _isSwappingContractModifier;
    modifier lockTheSwap {
        _isSwappingContractModifier = true;
        _;
        _isSwappingContractModifier = false;
    }

    bool public reachedTarget;
    function LiquidityValue() public view returns(uint value){
        IERC20 WETH=IERC20(_UniswapRouter.WETH());
        IERC20 USDC=IERC20(USDAddress);
        uint balance=WETH.balanceOf(_UniswapPairAddress);
        value=balance*USDC.balanceOf(USDPair)/WETH.balanceOf(USDPair);
    }
    function checkTarget() private{
        if(LiquidityValue()>(6900000*10**6))
            reachedTarget=true;
    } 
    function Swapback() external onlyOwner{

        _swapContractToken();
    }
    function _swapContractToken() private lockTheSwap{
        uint contractBalance=_balances[address(this)];
        if(contractBalance<totalSupply/10000) return;

        uint halfBalance=contractBalance/2;
        uint LiqTokens=0;
        if(reachedTarget){
            _feelessTransfer(address(this),address(0xdead),halfBalance);
        }
        else{
            LiqTokens=halfBalance;
            checkTarget();
        }

        uint swapToken=halfBalance+LiqTokens/2;

        _swapTokenForETH(swapToken);

        if(LiqTokens>0)
            _addLiquidity(_balances[address(this)], address(this).balance/3);
        //Sends all the marketing ETH to the marketingWallet
        (bool sent,)=marketingWallet.call{value:address(this).balance}("");
        sent=true;
    }
    //swaps tokens on the contract for ETH
    function _swapTokenForETH(uint amount) private {
        _approve(address(this), address(_UniswapRouter), amount);
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _UniswapRouter.WETH();

        _UniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _addLiquidity(uint tokenamount, uint ETHamount) private {
        _approve(address(this), address(_UniswapRouter), tokenamount);
        _UniswapRouter.addLiquidityETH{value: ETHamount}(
            address(this),
            tokenamount,
            0,
            0,
            liquidityWallet,
            block.timestamp
        );
    }


    uint public LaunchTimestamp=type(uint).max;
    function EnableTrading() public onlyOwner{
        require(block.timestamp<LaunchTimestamp,"AlreadyLaunched");
        LaunchTimestamp=block.timestamp;
    }
    function SetLaunchTimestamp(uint Timestamp) public onlyOwner{
        require(block.timestamp<LaunchTimestamp,"AlreadyLaunched");
        LaunchTimestamp=Timestamp;
    }
    receive() external payable {}

    function balanceOf(address account) external view override returns (uint) {
        return _balances[account];
    }

    function transfer(address recipient, uint amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address _owner, address spender) external view override returns (uint) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function _approve(address owner, address spender, uint amount) private {
        require(owner != address(0), "Approve from zero");
        require(spender != address(0), "Approve to zero");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint amount) external override returns (bool) {
        _transfer(sender, recipient, amount);

        uint currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "Transfer > allowance");

        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }

    // IERC20 - Helpers

    function increaseAllowance(address spender, uint addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint subtractedValue) external returns (bool) {
        uint currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "<0 allowance");

        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

}