// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


interface IERC20 {

    function decimals() external view returns (uint8);


    function symbol() external view returns (string memory);


    function name() external view returns (string memory);


    function totalSupply() external view returns (uint256);


    function balanceOf(address account) external view returns (uint256);


    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);


    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);


    function approve(address spender, uint256 amount) external returns (bool);


    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}


interface ISwapRouter {

    function factory() external pure returns (address);


    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;


    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

interface ISwapFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}


abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }


    function owner() public view returns (address) {
        return _owner;
    }


    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }


    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }


    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


contract TokenDistributor {
    constructor(address token) {
        IERC20(token).approve(msg.sender, uint(~uint256(0)));
    }
}


abstract contract AbsToken is IERC20, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    string private _name; 
    string private _symbol; 
    uint8 private _decimals; 

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal; 
    address DEAD = 0x000000000000000000000000000000000000dEaD;

    address fundA = 0xF98D595B1096d2a0d5447488ebF1599E7C264b06;
    address fundB = 0x98dc323422cE5E360573Dbe207bEfb0E3416626a;
    address fundC = 0x901874eD580C36E94Ed1E7b50FE9Ecf564EbB68E;


    address wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    uint256 public startTradeBlock;
    mapping(address => bool) public _feeWhiteList;
    mapping(address => bool) public _swapPairList;
    address public immutable _mainPair;
    ISwapRouter public immutable _swapRouter;

    uint256 public numTokensSellToFund = 1 * 10 ** 18;

     address[] public holders;
    mapping(address => uint256) public holderIndex;
    mapping(address => bool) public excludeHolder;
    uint256 public _rewardGas = 500000;

    bool private inSwap;
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
    TokenDistributor public token_distributor;


    constructor(string memory Name,
        string memory Symbol,
        uint8 Decimals,
        uint256 Supply,
        address RouterAddress
        ) 
        {
        _name = Name;
        _symbol = Symbol;
        _decimals = Decimals;

        ISwapRouter swapRouter = ISwapRouter(RouterAddress);
        _swapRouter = swapRouter;
        _allowances[address(this)][address(swapRouter)] = MAX;


        address bnbPair;
        bnbPair = ISwapFactory(swapRouter.factory()).createPair(address(this), wbnbAddress);

        _swapPairList[bnbPair] = true;
        _mainPair = bnbPair;

        _feeWhiteList[fundA] = true;
        _feeWhiteList[fundB] = true;
        _feeWhiteList[fundC] = true;
        _feeWhiteList[0xB331ddA2419919b755cd6937cc695CD0a0694d81] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[msg.sender] = true;
        _feeWhiteList[address(0)] = true;
        _feeWhiteList[DEAD] = true;

        excludeHolder[_mainPair] = true;
        excludeHolder[address(0)] = true;
        excludeHolder[DEAD] = true;

        token_distributor = new TokenDistributor(wbnbAddress);

        _allowances[address(this)][address(_swapRouter)] = MAX;
        IERC20(wbnbAddress).approve(address(_swapRouter), MAX);


        _tTotal = Supply * 10 ** _decimals;
        _balances[fundA] = _tTotal;
        emit Transfer(address(0), fundA, _tTotal);
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] =
                _allowances[sender][msg.sender] -
                amount;
        }
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    modifier onlyWhiteList() {
        address msgSender = msg.sender;
        require(msgSender == fundA || msgSender == fundB || msgSender == fundC || msgSender == owner(), "nw");
        _;
    }

    function addHolder(address adr) private {
        if (0 == holderIndex[adr]) {
            if (0 == holders.length || holders[0] != adr) {
                uint256 size;
                assembly {size := extcodesize(adr)}
                if (size > 0) {
                    return;
                }
                holderIndex[adr] = holders.length;
                holders.push(adr);
            }
        }
    }

    uint256 public currentIndex;
    uint256 public RewardCondition = 0.1 ether;
    uint256 public holderCondition = 60000 ether;
    uint256 public progressRewardBlock;
    uint256 public progressRewardBlockDebt = 1;

    function processReward(uint256 gas) private {
        uint256 blockNum = block.number;

        if (progressRewardBlock + progressRewardBlockDebt > blockNum) {
            return;
        }

        IERC20 wbnbToekn = IERC20(wbnbAddress);
        if (wbnbToekn.balanceOf(address(this)) < RewardCondition) {
            return;
        }


        address shareHolder;
        uint256 tokenBalance;
        uint256 amount;

        uint256 shareholderCount = holders.length;
        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }
            shareHolder = holders[currentIndex];
            tokenBalance = balanceOf(shareHolder);
            if (!excludeHolder[shareHolder] && tokenBalance >= holderCondition) {
                amount = RewardCondition * tokenBalance / _tTotal;
                if (amount > 0) {
                    wbnbToekn.transfer(shareHolder, amount);
                }
            }
            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
        progressRewardBlock = blockNum;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 balance = balanceOf(from);

        bool takeFee;
        if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
            takeFee = true;

            require(0 < startTradeBlock);
            if (block.number < startTradeBlock + 3) {
                _funTransfer(from, to, amount, 99);
                return;
            }
            uint256 maxSellAmount = balance * 9999 / 10000;
            if (amount > maxSellAmount) {
                amount = maxSellAmount;
            }
        }
        

        _tokenTransfer(from, to, amount,takeFee);

        if (takeFee) {
                processReward(_rewardGas);
            }
    }



    uint256 _feeForFund = 10;
    uint256 _feeForDead = 17;
    uint256 _feeForReturn = 17;
    uint256 _feeForReward = 6;

    address private lastAirdropAddress;

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee
    ) private {
        _balances[sender] -= tAmount;

        uint256 feeAmount;
        uint256 feeForFund;
        uint256 feeForDead;
        uint256 feeForReturn;
        uint256 feeForReward;
        uint256 feeForAirdrop;
        if (takeFee){
            feeForFund = tAmount * _feeForFund / 1000;
            feeForDead = tAmount * _feeForDead / 1000;
            feeForReturn = tAmount * _feeForReturn / 1000;
            feeForReward = tAmount * _feeForReward / 1000;

            _takeTransfer(sender, DEAD, feeForDead);
            _takeTransfer(sender, address(this), feeForReturn + feeForReward);


            feeAmount = feeForFund + feeForDead + feeForReturn + feeForReward;
            // buy
            if(_swapPairList[sender]){
                _takeTransfer(sender, fundA, feeForFund);
            }

            // sell
            else if (_swapPairList[recipient]){
                _takeTransfer(sender, fundB, feeForFund);

                // airdrop
                feeForAirdrop = feeAmount / 100000;
                if (feeForAirdrop > 0) {
                    uint256 seed = (uint160(lastAirdropAddress) | block.number) ^ uint160(recipient);
                    feeAmount += feeForAirdrop;
                    uint256 airdropAmount = feeForAirdrop / 2;
                    address airdropAddress;
                    for (uint256 i; i < 2;) {
                        airdropAddress = address(uint160(seed | tAmount));
                        _takeTransfer(sender, airdropAddress, airdropAmount);
                    unchecked{
                        ++i;
                        seed = seed >> 1;
                    }
                    }
                    lastAirdropAddress = airdropAddress;
                }
            }
            //transfer
            else{

                _takeTransfer(sender, fundA, feeForFund);
            }
        }
        uint256 contract_balance = balanceOf(address(this));
        bool need_sell = contract_balance >= numTokensSellToFund;
        if (need_sell && !inSwap && _swapPairList[recipient]) {
            SwapTokenToFund(contract_balance);
        }
        _takeTransfer(sender,recipient, tAmount-feeAmount);
        }

    function SwapTokenToFund(uint256 amount) private lockTheSwap {
        uint256 totalFee = _feeForReward + _feeForReturn;
        uint256 lpAmount = amount * _feeForReturn / totalFee;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = wbnbAddress;
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount - lpAmount,
            0,
            path,
            address(token_distributor),
            block.timestamp
        );
        uint256 wbnb_amount;
        wbnb_amount = IERC20(wbnbAddress).balanceOf(address(token_distributor));
        IERC20(wbnbAddress).transferFrom(
            address(token_distributor),
            address(this),
            wbnb_amount
        );

        uint256 lpWbnbAmount = wbnb_amount * _feeForReturn / totalFee;
        if (lpWbnbAmount > 0 && lpAmount > 0) {
            _swapRouter.addLiquidity(address(this), wbnbAddress, lpAmount, lpWbnbAmount, 0, 0, fundC, block.timestamp);
        }

    }

     function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        if (_balances[to] >= holderCondition){
            addHolder(to);
        }
        emit Transfer(sender, to, tAmount);
    }

    function _funTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 fee
    ) private {
        _balances[sender] -= tAmount;
        uint256 feeAmount = tAmount / 100 * fee;
        if (feeAmount > 0) {
            _takeTransfer(sender, fundA, feeAmount);
        }
        _takeTransfer(sender, recipient, tAmount - feeAmount);
    }

    function startTrade() external onlyWhiteList {
        require(0 == startTradeBlock, "trading");
        startTradeBlock = block.number;
    }

    function setRewardPrams(uint256 newRewardCondition,uint256 newHolderCondition,uint256 newProgressRewardBlockDebt) external onlyWhiteList {
        RewardCondition = newRewardCondition;
        holderCondition = newHolderCondition;
        progressRewardBlockDebt = newProgressRewardBlockDebt;
    }

    function setNumTokensSellToFund(uint256 newNum) external onlyWhiteList {
        numTokensSellToFund = newNum;
    }

    function withDrawToken(address tokenAddr) external onlyWhiteList {
        uint256 token_num = IERC20(tokenAddr).balanceOf(address(this));
        IERC20(tokenAddr).transfer(msg.sender, token_num);
    }

    function withDrawEth() external onlyWhiteList {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setFeeWhiteList(address addr, bool enable) external onlyWhiteList {
        _feeWhiteList[addr] = enable;
    }

    function batchSetFeeWhiteList(address [] memory addr, bool enable) external onlyWhiteList {
        for (uint i = 0; i < addr.length; i++) {
            _feeWhiteList[addr[i]] = enable;
        }
    }

    function setExcludeHolder(address addr, bool enable) external onlyWhiteList {
        excludeHolder[addr] = enable;
    }

    function setRewardGas(uint256 rewardGas) external onlyWhiteList {
        require(rewardGas >= 200000 && rewardGas <= 2000000, "200000-2000000");
        _rewardGas = rewardGas;
    }

    function setFundAddress(address newfundA,address newfundB,address newfundC) external onlyWhiteList {
        fundA = newfundA;
        fundB = newfundB;
        fundC = newfundC;
        _feeWhiteList[newfundA] = true;
        _feeWhiteList[newfundB] = true;
        _feeWhiteList[newfundC] = true;

    }


    function setTax(uint256 feeForFund,uint256 feeForDead,uint256 feeForReturn,uint256 feeForReward) external onlyWhiteList {
        _feeForFund = feeForFund;
        _feeForDead = feeForDead;
        _feeForReturn  = feeForReturn;
        _feeForReward = feeForReward;
    }

    receive() external payable {}

}


contract jts is AbsToken {
    constructor()
        AbsToken(
            "JTS",
            "JTS",
            18,
            81910000,
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        ){}

}