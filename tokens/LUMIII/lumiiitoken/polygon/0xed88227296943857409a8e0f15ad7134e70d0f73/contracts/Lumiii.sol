// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.6;


import "./LumiiiGovernance.sol";
import "./LumiiiReflections.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract LumiiiToken is Context, IERC20, LumiiiGovernance, LumiiiReflections {

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    constructor (address charityWallet, address opsWallet, address routerAddress) public {
        _rOwned[_msgSender()] = _rTotal;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddress);
         // Create a uniswap pair for this new token 

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        // Set charity and ops wallets
        _charityWallet = charityWallet;
        _opsWallet = opsWallet;
        
        //exclude owner, contract, charity wallet, and ops wallet from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        // Exclude charity and ops wallet from rewards
        excludeFromReward(_charityWallet);
        excludeFromReward(_opsWallet);
        excludeFromReward(address(0));
        
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    /** 
        @notice Returns name of token
    */
    function name() public view returns (string memory) {
        return _name;
    }

    /** 
        @notice Returns symbol of token
    */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /** 
        @notice Returns symbol of token
    */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /** 
        @notice Returns total supply of token
    */
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    /** 
        @notice Returns token balance for an account
        @param account The address to check balance of
    */
    function balanceOf(address account) public view override returns (uint256) {
        // If account is excluded from fees, return true amount owned
        if (_isExcluded[account]) return _tOwned[account];
        // Return reflected amount owned converted to true amount
        return tokenFromReflection(_rOwned[account]);
    }

    /** 
        @notice Transfers tokens from msg.sender to recipient
        @param recipient address of transfer recipient
        @param amount token amount to transfer
    */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        _moveDelegates(_delegates[msg.sender], _delegates[recipient], amount);
        return true;
    }

    /** 
        @notice Delegate votes from msg.sender to delegatee
        @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        uint256 delegatorBalance = balanceOf(msg.sender);

        address currentDelegate = _delegates[msg.sender]; // Will be 0 address if msg.sender has no delegates
        _delegates[msg.sender] = delegatee;

        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    /**
        @notice Get allowance for a user
        @param owner address giving allowance
        @param spender address spending tokens from owner
    */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
        @notice Approve user to spend tokens from msg.sender
        @param spender address of user spending tokens
        @param amount token amount to approve
    */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /** 
        @notice Transfers tokens from sender to recipient
        @param sender Address to send tokens from
        @param recipient Address receiving tokens
        @param amount Amount to transfer
    */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "amount exceeds allowance"));
        _moveDelegates(_delegates[sender], _delegates[recipient], amount);
        return true;
    }

    /** 
        @notice Increase allowance of a user
        @param spender Address to increase allowance of
        @param addedValue Amount to increase allowance by
    */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /** 
        @notice Decrease allowance of a user
        @param spender Address to decrease allowance of
        @param subtractedValue Amount to decrease allowance by
    */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "decreased allowance below zero"));
        return true;
    }

    /** 
        @notice Set a new charity walllet
        @param newWallet Address of new charity wallet
    */
    function setCharityWallet(address newWallet) external onlyOwner() {
        // Include old wallet
        includeInReward(_charityWallet);

        _charityWallet = newWallet;

        //Exclude new wallet
        excludeFromReward(_charityWallet);
    }

    /** 
        @notice Set new operations wallet
        @param newWallet Address of new operations wallet
    */
    function setOpsWallet(address newWallet) external onlyOwner() {
        // Include old wallet
        includeInReward(_opsWallet);

        _opsWallet = newWallet;

        // Exclude new wallet
        excludeFromReward(_opsWallet);
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    /** 
        @notice Helper function for approve
    */
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "approve from zero address");
        require(spender != address(0), "approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /** 
        @notice Helper function for transfer. Checks if transfer is valid, fees are taken, and if liquidity swap
        should occour
    */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        // Check if transfer is valid
        require(from != address(0), "transfer from zero address");
        require(to != address(0), "transfer to zero address");
        require(amount > 0, "amount not greater than zero");
        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "amount exceeds maxTxAmount");

        uint256 contractTokenBalance = balanceOf(address(this));
        
        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }
        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        // check balance and add liquidity if needed
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);
    }

    /** 
        @notice Swap tokens of local liquidity pool and add to uniswap pool
    */
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    /** 
        @notice Swaps LUMIII token for ETH
    */
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    /** 
        @notice Add liquidity to uniswap pool
    */
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    // function deliver(uint256 tAmount) public {
    //     address sender = _msgSender();
    //     require(!_isExcluded[sender], "Excluded addresses cannot call this function");
    //     (uint256 rAmount,,) = _getValues(tAmount);
    //     _rOwned[sender] = _rOwned[sender].sub(rAmount);
    //     _rTotal = _rTotal.sub(rAmount);
    //     _tFeeTotal = _tFeeTotal.add(tAmount);
    // }

}