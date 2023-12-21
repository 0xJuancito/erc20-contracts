//SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./interfaces/IOcean.sol";
import "./interfaces/IDistributor.sol";

contract FathomToken is IERC20, Ownable {
    using SafeMath for uint256;

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    string constant _name = "Fathom";
    string constant _symbol = "FATHOM";
    uint8 constant _decimals = 18;

    uint256 _totalSupply = 1000000000 * (10 ** _decimals);

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    mapping(address => bool) public pairs; //currency => pair per token

    mapping(address => bool) isFeeExempt;
    // allowed users to do transactions before trading enable
    mapping(address => bool) isAuthorized;
    mapping(address => bool) isMaxTxExcluded;

    mapping(address => uint256) public blacklistedTill;
    mapping(address => uint256) public totalPurchased;
    mapping(address => uint256) public totalSells;

    uint256 public totalBuyTaxCollected;
    uint256 public totalSellTaxCollected;

    // buy fees
    uint256 public buySwapCharge = 14;
    uint256 public buyShillingCharge = 1;
    uint256 public buyTotalCharge = 15;
    // Set the Buy Charges
    uint256 public sellSwapCharge = 5;
    uint256 public sellShillingCharge = 0;
    uint256 public sellTotalCharge = 5;

    uint256 public jetStreamSwap = 75;
    uint256 public devopsSwap = 25;

    address public jetStreamWallet = 0x364e47E4611A446aB0E0Df9054673930eeb313ec;
    address public devopsWallet = 0x65242Cc63a6f138f5850bc1F41f4A1BC5e41aed9;

    IOcean public ocean = IOcean(0x2182707ad8A746a9eEd08fb95F31825B5e9E5c95);

    IUniswapV2Router02 public router;
    address public pair;

    IDividendDistributor public shillingDistributor;

    bool public tradingOpen = true;

    event AutoLiquify(uint256 amountBNB, uint256 amountBOG);
    bool public swapEnabled = true;
    uint256 public swapThreshold = (_totalSupply * 10) / 10000; // 0.01% of supply
    uint256 public maxTxLimit = _totalSupply / 1000;
    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IUniswapV2Factory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );

        pairs[pair] = true;

        _allowances[address(this)][address(router)] = type(uint256).max;

        isFeeExempt[msg.sender] = true;

        isAuthorized[owner()] = true;

        isMaxTxExcluded[msg.sender] = true;
        isMaxTxExcluded[pair] = true;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    modifier notBlacklisted(address _user) {
        require(
            block.timestamp >= blacklistedTill[_user],
            "FathomToken: User is blacklisted"
        );
        _;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
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

    function currentBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address holder,
        address spender
    ) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function manageBlacklistUsers(
        address[] memory _users,
        uint256[] memory _unblockTimes
    ) external onlyOwner {
        require(
            _users.length == _unblockTimes.length,
            "FathomToken: length of users and unblockTimes must be same"
        );
        for (uint256 i = 0; i < _users.length; i++) {
            blacklistedTill[_users[i]] = _unblockTimes[i];
        }
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender]
                .sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal notBlacklisted(sender) notBlacklisted(recipient) returns (bool) {
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (!isAuthorized[sender]) {
            require(tradingOpen, "Trading not open yet");
        }
        if (!isMaxTxExcluded[sender] && !isMaxTxExcluded[recipient]) {
            require(amount <= maxTxLimit, "Max Transaction limit exceeded");
        }
        if (shouldSwapBack(recipient)) {
            swapBackInBnb();
        }

        //Exchange tokens
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );

        uint256 amountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, amount, recipient)
            : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function shouldTakeFee(
        address sender,
        address to
    ) internal view returns (bool) {
        if (isFeeExempt[sender] || isFeeExempt[to]) {
            return false;
        } else {
            return true;
        }
    }

    function takeFee(
        address sender,
        uint256 amount,
        address to
    ) internal returns (uint256) {
        uint256 feeAmount = 0;
        uint256 shillingFee = 0;
        if (pairs[to]) {
            totalSells[sender] += amount;
            // call ocean
            try ocean.wave() {} catch {}

            try shillingDistributor.claimStaking() {} catch {}

            feeAmount = amount.mul(sellTotalCharge).div(100);
            // sell tax
            totalSellTaxCollected += feeAmount;

            if (sellShillingCharge > 0)
                shillingFee = feeAmount.mul(sellShillingCharge).div(
                    sellTotalCharge
                );
        } else if (pairs[sender]) {
            totalPurchased[to] += amount;
            // call ocean
            try ocean.wave() {} catch {}
            try shillingDistributor.claimStaking() {} catch {}

            feeAmount = amount.mul(buyTotalCharge).div(100);
            totalBuyTaxCollected += feeAmount;
            if (buyShillingCharge > 0)
                shillingFee = feeAmount.mul(buyShillingCharge).div(
                    buyTotalCharge
                );
        }

        if (shillingFee > 0) {
            _balances[address(shillingDistributor)] = _balances[
                address(shillingDistributor)
            ].add(shillingFee);
            emit Transfer(sender, address(shillingDistributor), shillingFee);

            try shillingDistributor.deposit(shillingFee) {} catch {}
        }
        if (feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(
                feeAmount.sub(shillingFee)
            );
            emit Transfer(sender, address(this), feeAmount.sub(shillingFee));
        }

        return amount.sub(feeAmount);
    }

    function shouldSwapBack(address to) internal view returns (bool) {
        return
            pairs[to] &&
            !inSwap &&
            tradingOpen &&
            swapEnabled &&
            _balances[address(this)] >= swapThreshold;
    }

    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
        uint256 amountBNB = address(this).balance;
        payable(msg.sender).transfer((amountBNB * amountPercentage) / 100);
    }

    function updateBuyFees(
        uint256 _swapping,
        uint256 _shilling
    ) public onlyOwner {
        buySwapCharge = _swapping;
        buyShillingCharge = _shilling;

        buyTotalCharge = _swapping.add(_shilling);
        require(buyTotalCharge <= 20, "Total Fees can not be grater than 20%");
    }

    function updateSellFees(
        uint256 _swapping,
        uint256 _shilling
    ) public onlyOwner {
        sellSwapCharge = _swapping;
        sellShillingCharge = _shilling;

        sellTotalCharge = _swapping.add(_shilling);
        require(sellTotalCharge <= 20, "Total Fees can not be grater than 20%");
    }

    function updateSwapAmounts(
        uint256 jetStream,
        uint256 devops
    ) public onlyOwner {
        jetStreamSwap = jetStream;
        devopsSwap = devops;

        uint256 totalSwap = jetStream.add(devops);

        require(
            totalSwap == 100,
            "Total swap percentages should equal to 100%"
        );
    }

    // switch Trading
    function enableTrading() public onlyOwner {
        tradingOpen = true;
    }

    function whitelistPreSale(address _preSale) public onlyOwner {
        isFeeExempt[_preSale] = true;
        isAuthorized[_preSale] = true;
    }

    function swapBackInBnb() internal swapping {
        uint256 contractTokenBalance = _balances[address(this)];

        if (contractTokenBalance > swapThreshold)
            contractTokenBalance = swapThreshold;

        // swap the tokens
        swapTokensForEth(contractTokenBalance);
        // get swapped bnb amount
        uint256 swappedBnbAmount = address(this).balance;

        uint256 bnbToJetStream = swappedBnbAmount.mul(jetStreamSwap).div(100);

        uint256 bnbToDevops = swappedBnbAmount.sub(bnbToJetStream);
        // calculate reward bnb amount
        if (bnbToJetStream > 0)
            payable(jetStreamWallet).transfer(bnbToJetStream);

        if (bnbToDevops > 0) payable(devopsWallet).transfer(bnbToDevops);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);
        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    function changeFeeReceiver(
        address _jetStream,
        address _devops
    ) external onlyOwner {
        jetStreamWallet = _jetStream;
        devopsWallet = _devops;
    }

    function setPairs(address _pairAddress, bool _status) external onlyOwner {
        pairs[_pairAddress] = _status;
    }

    function changeRouter(address _router) external onlyOwner {
        router = IUniswapV2Router02(_router);
    }

    function setSwapBackSettings(
        bool _enabled,
        uint256 _amount
    ) external onlyOwner {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function changeMaxTxLimit(uint256 _maxLimit) external onlyOwner {
        require(
            _maxLimit >= 1000000,
            "Max transaction limit should grater than 0.1%"
        );

        maxTxLimit = _maxLimit * 10 ** 18;
    }

    function excludeFromMaxTx(
        address _wallet,
        bool _status
    ) external onlyOwner {
        isMaxTxExcluded[_wallet] = _status;
    }

    function setOcean(IOcean _ocean) external onlyOwner {
        ocean = _ocean;
    }

    function setShillingDistributor(
        address _shillingDistributors
    ) external onlyOwner {
        shillingDistributor = IDividendDistributor(_shillingDistributors);
    }
}
