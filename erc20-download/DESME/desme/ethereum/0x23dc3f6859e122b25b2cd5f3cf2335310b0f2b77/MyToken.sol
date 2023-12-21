//www.desme.io t.me/DesmeOfficial
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            uint256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            uint256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract PriceConsumerV3 {
    AggregatorV3Interface internal priceFeed;

    function getLatestPrice() public view returns (uint) {
        (, uint price, , , ) = priceFeed.latestRoundData();

        return uint256(price);
    }
}


interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract MyToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    bool public isAntiWhaleEnabled;
    uint256 public antiWhaleThreshold;
    uint256 public tax;
    uint256 public limitTaxes = 1000000000;
    uint256 public totalTokens;
    uint256 public rewardTaxPercentage;
    uint256 public investmentTaxPercentage;
    uint256 public maintenanceTaxPercentage;
    uint256 public divided = 100;
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool public SwapEnabled;
    uint256 public launchTimestamp;
    uint256 public interval = 30 days;
    uint256 public  startTradingTime = 40 minutes;
    uint256 send = 42500000000;
    address payable public investmentWallet;
    address payable public maintenanceWallet;
    address payable public rewardWallet;

    uint256 public tokensDistributed = 0;
    uint256 public lastDistributionTime;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public ExcludedFromFee;

    event investWallet(address indexed wallet);
    event mainWallet(address indexed wallet);
    event marketWallet(address indexed wallet);
    event MonthlyWithdrawal(
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    constructor(
        string memory _name, string memory _symbol
        ) {
        name = _name ;
        symbol = _symbol;
        decimals = 5;
        totalSupply = 1_00_000_000 * 10 ** uint256(decimals);
        balances[owner()] = ((totalSupply).mul(949)).div(1000);
        totalTokens = ((totalSupply).mul(51)).div(1000);
        ExcludedFromFee[owner()] = true;
        ExcludedFromFee[address(this)] = true;
        ExcludedFromFee[investmentWallet] = true;
        ExcludedFromFee[maintenanceWallet] = true;
        ExcludedFromFee[rewardWallet] = true;
        launchTimestamp = block.timestamp;
        lastDistributionTime = block.timestamp;
        antiWhaleThreshold = (totalSupply * 5) / 1000; // 0.5% of the total supply
        rewardTaxPercentage = 10;
        investmentTaxPercentage = 15;
        maintenanceTaxPercentage = 15;

        investmentWallet = payable(0xb5fc14ee4DBA399F9043458860734Ed33FdCd96E);
        maintenanceWallet = payable(0x5a8c6eDC91fe3132130899b85c10E77BCEEa17ee);
        rewardWallet = payable(0xc29724f5261faC059A2aA2af88013fDefb7BAae2);

        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D  //mainnat uniswap router v2 address
        );

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address _owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function setLimitTaxes(uint256 newLimit) external onlyOwner {
        limitTaxes = newLimit;
    }

    function setExcludedFromFee(
        address account,
        bool isExcluded
    ) external onlyOwner {
        if (ExcludedFromFee[account] != isExcluded) {
            ExcludedFromFee[account] = isExcluded;
        } else {
            revert("Exclusion status is already set to the desired value");
        }
    }

    function setAntiWhale(bool enabled, uint256 threshold) external onlyOwner {
        isAntiWhaleEnabled = enabled;
        antiWhaleThreshold = threshold;
    }

    function setInvestmentWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        investmentWallet = payable(wallet);
        emit investWallet(wallet);
    }

    function setMaintenanceWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        maintenanceWallet = payable(wallet);
        emit mainWallet(wallet);
    }

    function setrewardWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        rewardWallet = payable(wallet);
        emit marketWallet(wallet);
    }

    function setTaxPercentages(
        uint256 investmentTax,
        uint256 maintenanceTax,
        uint256 rewardTax
    ) internal {
        // Ensure tax percentages are not greater than 100
        require(
            investmentTax + maintenanceTax + rewardTax <= 100,
            "Total tax exceeds 100%"
        );

        investmentTaxPercentage = investmentTax;
        maintenanceTaxPercentage = maintenanceTax;
        rewardTaxPercentage = rewardTax;
    }

    function updateTaxPercentages(
        uint256 investmentTax,
        uint256 maintenanceTax,
        uint256 rewardTax
    ) external onlyOwner {
        setTaxPercentages(investmentTax, maintenanceTax, rewardTax);
    }

    function pauseTrading() external onlyOwner {
        SwapEnabled = false;
    }

    function StartTrading() external onlyOwner {
        require(!SwapEnabled, "Trading is already enabled");
        require(
            block.timestamp >= launchTimestamp + startTradingTime,
            "Too early to update fees"
        );
        isAntiWhaleEnabled = false;
        SwapEnabled = true;
        setTaxPercentages(2, 2, 1);
        renounceOwnership();
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(amount <= balances[from], "Insufficient balance");
        if (from == uniswapV2Pair || to == uniswapV2Pair) {
            if (!ExcludedFromFee[from] && !ExcludedFromFee[to]) {
                uint256 investmentTax = amount.mul(investmentTaxPercentage).div(
                    divided
                ); // 20% Investment
                uint256 buybackTax = amount.mul(maintenanceTaxPercentage).div(
                    divided
                ); // 20% Buybacks
                uint256 rewardTax = amount.mul(rewardTaxPercentage).div(
                    divided
                ); // 10% reward
                tax = tax.add(investmentTax.add(buybackTax).add(rewardTax));
                uint256 transferAmount = amount
                    .sub(investmentTax)
                    .sub(buybackTax)
                    .sub(rewardTax);

                if (isAntiWhaleEnabled) {
                    require(
                        amount <= antiWhaleThreshold,
                        "Transfer amount exceeds the anti-whale threshold"
                    );
                }

                balances[from] = balances[from].sub(amount);
                balances[to] = balances[to].add(transferAmount);
                emit Transfer(from, to, transferAmount);
                balances[address(this)] = balances[address(this)].add(
                    investmentTax.add(buybackTax).add(rewardTax)
                );
                emit Transfer(
                    from,
                    address(this),
                    investmentTax.add(buybackTax).add(rewardTax)
                );
            } else {
                balances[from] = balances[from].sub(amount);
                balances[to] = balances[to].add(amount);
                emit Transfer(from, to, amount);
            }
        } else {
            balances[from] = balances[from].sub(amount);
            balances[to] = balances[to].add(amount);
            emit Transfer(from, to, amount);

            bool shouldSell = tax >= limitTaxes;

            if (SwapEnabled && shouldSell && from != uniswapV2Pair) {
                swapTokensForEth(tax);
                _distributeTax();
                tax = 0;
            }
        }
    }

    function _distributeTax() internal {
        uint256 contractETHBalance = address(this).balance;
        uint256 totaltax = investmentTaxPercentage +
            maintenanceTaxPercentage +
            rewardTaxPercentage;
        uint256 investment = (contractETHBalance)
            .mul(investmentTaxPercentage)
            .div(totaltax);
        uint256 maintenance = (contractETHBalance)
            .mul(maintenanceTaxPercentage)
            .div(totaltax);
        uint256 reward = (contractETHBalance).mul(rewardTaxPercentage).div(
            totaltax
        );

        payable(investmentWallet).transfer(investment);
        payable(maintenanceWallet).transfer(maintenance);
        payable(rewardWallet).transfer(reward);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp + 360
        );
    }

    function withdrawEth(uint256 amount) external onlyOwner {
        require(
            amount <= address(this).balance,
            "Insufficient contract balance"
        );
        payable(msg.sender).transfer(amount);
    }

    function distributeTokens() external {
        require(
            block.timestamp >= lastDistributionTime + interval,
            "Not enough time has passed since the last distribution"
        );
        require(
            tokensDistributed + send <= totalTokens,
            "All tokens have been distributed"
        );
        tokensDistributed += send;
        balances[owner()] += send;
        lastDistributionTime = block.timestamp;
    }

    function canCallDistributeTokens() public view returns (uint256) {
        if (block.timestamp >= lastDistributionTime + interval) {
            return 0; // The function can be called now
        } else {
            return lastDistributionTime + interval;
        }
    }

    receive() external payable {}
}