// SPDX-License-Identifier: Unlicensed
//
//   __    __     ______     _____       __
//  |  |  |  |   /  __  \   |      \    |  |
//  |  |__|  |  |  |  |  |  |   _   \   |  |
//  |   __   |  |  |  |  |  |  |_)   |  |  |
//  |  |  |  |  |  `--'  |  |       /   |  |____
//  |__|  |__|   \______/   |_____ /    |_______|
//
//
// Website: hodltoken.net
// Telegram: t.me/hodlinvestorgroup
// Twitter: twitter.com/hodl_official
//
//
pragma solidity 0.8.19;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param ticketsToDraw - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 ticketsToDraw
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IBEP20 {
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

interface IWBNB {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    receive() external payable;

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function totalSupply() external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private initializing;

    /**
     * @dev Modifier to use in the initializer function of a contract.
     */
    modifier initializer() {
        require(
            initializing || isConstructor() || !initialized,
            "Contract instance has already been initialized"
        );

        bool isTopLevelCall = !initializing;
        if (isTopLevelCall) {
            initializing = true;
            initialized = true;
        }

        _;

        if (isTopLevelCall) {
            initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        assembly {
            cs := extcodesize(self)
        }
        return cs == 0;
    }

    // Reserved storage space to allow for layout changes in the future.
    uint256[50] private ______gap;
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context, Initializable {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {}

    function initOwner(address owner_) public initializer {
        _owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
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
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IPancakeFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

interface IPancakePair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IPancakeRouter01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountETHDesired,
        uint256 amountAMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountETH,
            uint256 liquidity
        );

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
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountETH);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountETH);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(

        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    /*
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountETH);
    */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

// File: contracts/protocols/bep/Utils.sol
library Utils {

    function calculateBNBReward(
        uint256 currentBalance,
        uint256 currentBNBPool,
        uint256 totalSupply,
        uint256 rewardHardcap
    ) public pure returns (uint256) {
        uint256 bnbPool = currentBNBPool > rewardHardcap ? rewardHardcap : currentBNBPool;
        return bnbPool * currentBalance / totalSupply;
    }

    function calculateTopUpClaim(
        uint256 currentRecipientBalance,
        uint256 basedRewardCycleBlock,
        uint256 threshHoldTopUpRate,
        uint256 amount
    ) public pure returns (uint256) {
        uint256 rate = amount * 100 / currentRecipientBalance; 

        if (rate >= threshHoldTopUpRate) {
            uint256 incurCycleBlock = basedRewardCycleBlock * rate / 100;

            if (incurCycleBlock >= basedRewardCycleBlock) {
                incurCycleBlock = basedRewardCycleBlock;
            }

            return incurCycleBlock;
        }

        return 0;
    }

    function swapTokensForEth(address routerAddress, uint256 tokenAmount)
        public
    {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function swapETHForTokens(
        address routerAddress,
        address recipient,
        uint256 ethAmount
    ) public {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(this);

        // make the swap
        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(
            0, // accept any amount of BNB
            path,
            address(recipient),
            block.timestamp + 360
        );
    }

    function swapTokensForTokens(
        address routerAddress,
        address recipient,
        uint256 ethAmount
    ) public {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(this);

        // make the swap
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ethAmount, // wbnb input
            0, // accept any amount of BNB
            path,
            address(recipient),
            block.timestamp + 360
        );
    }

    function getAmountsout(uint256 amount, address routerAddress)
        public
        view
        returns (uint256 _amount)
    {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(this);

        // fetch current rate
        uint256[] memory amounts = pancakeRouter.getAmountsOut(amount, path);
        return amounts[1];
    }

    function addLiquidity(
        address routerAddress,
        address owner,
        uint256 tokenAmount,
        uint256 ethAmount
    ) public {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // add the liquidity
        pancakeRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner,
            block.timestamp + 360
        );
    }
    
    /**
    * @dev Returns the stacked amount of rewards. 
    *
    * First add reflections to the amount of stacked tokens. If the stackingRate is 0
    * stacking was started before refelctions were implemented into the contract. 
    * 
    * Then calculate the reward and check with the stacking limit.
    *
    *   "Scared money don't make money" - Billy Napier 
    */
    function calcStacked(HODLStruct.stacking memory tmpstacking, uint256 totalsupply, uint256 currentRate, uint256 stackingRate) public view returns (uint256) {
        uint256 reward;
        uint256 amount;

        uint256 stackedTotal = 1E6 + (block.timestamp-tmpstacking.tsStartStacking) * 1E6 / tmpstacking.cycle; 
        uint256 stacked = stackedTotal / 1E6;
        uint256 rest = stackedTotal - (stacked * 1E6);
        
        uint256 initialBalance = address(this).balance;

        if (stackingRate > 0)
        {
            amount = tmpstacking.amount * stackingRate / currentRate;
        } else {
            amount = tmpstacking.amount;
        }
        
        if (initialBalance >= tmpstacking.hardcap)
        {
            reward = uint256(tmpstacking.hardcap) * amount / totalsupply * stackedTotal / 1E6;
            if (reward >= initialBalance) reward = 0;

            if (reward == 0 || initialBalance - reward < tmpstacking.hardcap) 
            {
                reward = initialBalance - calcReward(initialBalance, totalsupply /amount, stacked, 15);
                reward += (initialBalance - reward) * amount / totalsupply * rest / 1E6; 
            }
        } else {
            reward = initialBalance - calcReward(initialBalance, totalsupply / amount, stacked, 15); 
            reward += (initialBalance - reward) * amount / totalsupply * rest / 1E6; 
        }

        return reward > tmpstacking.stackingLimit ? uint256(tmpstacking.stackingLimit) : reward;
    }

    /** 
    * @dev Computes `k * (1+1/q) ^ N`, with precision `p`. The higher
    * the precision, the higher the gas cost. To prevent overflows devide
    * exponent into 3 exponents with max n^10
    */
    function calcReward(uint256 coefficient, uint256 factor, uint256 exponent, uint256 precision) public pure returns (uint256) {
        
        precision = exponent < precision ? exponent : precision;
        if (exponent > 100) {
            precision = 30;
        }
        if (exponent > 200) exponent = 200;

        uint256 reward = coefficient;
        uint256 calcExponent = exponent * (exponent-1) / 2;
        uint256 calcFactor_1 = 1;
        uint256 calcFactor_2 = 1;
        uint256 calcFactor_3 = 1;
        uint256 i;

        for (i = 2; i <= precision; i += 2){
            if (i > 20) {
                calcFactor_1 = factor**10;
                calcFactor_2 = calcFactor_1;
                 calcFactor_3 = factor**(i-20);
            }
            else if (i > 10) {
                calcFactor_1 = factor**10;
                calcFactor_2 = factor**(i-10);
                calcFactor_3 = 1;
            }
            else {
                calcFactor_1 = factor**i;
                calcFactor_2 = 1;
                calcFactor_3 = 1;
            }
            reward += coefficient * calcExponent / calcFactor_1 / calcFactor_2 / calcFactor_3;
            calcExponent = i == exponent ? 0 : calcExponent * (exponent-i) * (exponent-i-1) / (i+1) / (i+2);  
        }
        
        calcExponent = exponent;

        for (i = 1; i <= precision; i += 2){
            if (i > 20) {
                calcFactor_1 = factor**10;
                calcFactor_2 = calcFactor_1;
                calcFactor_3 = factor**(i-20);
            }
            else if (i > 10) {
                calcFactor_1 = factor**10;
                calcFactor_2 = factor**(i-10);
                calcFactor_3 = 1;
            }
            else {
                calcFactor_1 = factor**i;
                calcFactor_2 = 1;
                calcFactor_3 = 1;
            }
            reward -= coefficient * calcExponent / calcFactor_1 / calcFactor_2 / calcFactor_3;
            calcExponent = i == exponent ? 0 : calcExponent * (exponent-i) * (exponent-i-1) / (i+1) / (i+2);  
        }

        return reward;
    }

    function _getValues(uint256 tAmount, uint256 currentRate, uint256 _taxFee, uint256 _liquidityFee)
        public
        pure
        returns (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        )
    {
        (
            tTransferAmount,
            tFee,
            tLiquidity
        ) = _getTValues(tAmount, _taxFee, _liquidityFee);
        (rAmount, rTransferAmount, rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            currentRate
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    function _getTValues(uint256 tAmount,uint256 _taxFee, uint256 _liquidityFee)
        private
        pure
        returns (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        )
    {      
        tFee = tAmount * _taxFee / (10**3); 
        tLiquidity = tAmount * _liquidityFee / (10**3); 
        tTransferAmount = tAmount - tFee - tLiquidity; 
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount * currentRate; 
        uint256 rFee = tFee * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate; 
        uint256 rTransferAmount = rAmount - rFee - rLiquidity;
        return (rAmount, rTransferAmount, rFee);
    }

    function getBonus(address wallet, address HodlHands, uint256 tokens, HODLStruct.HHBonus[5] memory HHBonus) public view returns (uint256) {

        uint256 amountHH = IWBNB(payable(address(HodlHands))).balanceOf(wallet);
        uint256 bonusTokens = 0;

        if (amountHH > 0) {
            if (amountHH >= HHBonus[4].threshold) {
                bonusTokens = tokens * HHBonus[4].bonus / 1000;
            } else if (amountHH >= HHBonus[3].threshold) {
                bonusTokens = tokens * HHBonus[3].bonus / 1000;
            } else if (amountHH >= HHBonus[2].threshold) {
                bonusTokens = tokens * HHBonus[2].bonus / 1000;
            } else if (amountHH >= HHBonus[1].threshold) {
                bonusTokens = tokens * HHBonus[1].bonus / 1000;
            } else if (amountHH >= HHBonus[0].threshold) {
                bonusTokens = tokens * HHBonus[0].bonus / 1000;
            }
        }

        return bonusTokens;
    }

}

library PancakeLibrary {

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "PancakeLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "PancakeLibrary: ZERO_ADDRESS");
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(
            IPancakeFactory(factory).getPair(tokenA, tokenB)
        ).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountETH) {
        require(amountA > 0, "PancakeLibrary: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "PancakeLibrary: INSUFFICIENT_LIQUIDITY"
        );
        amountETH = amountA * reserveB / reserveA;
    }

}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    modifier isHuman() {
        require(tx.origin == msg.sender, "sorry humans only");
        _;
    }
}

pragma experimental ABIEncoderV2;

contract HODL is Context, IBEP20, Ownable, ReentrancyGuard {

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) private _isExcludedFromMaxTx;

    // trace BNB claimed rewards and reinvest value
    mapping(address => uint256) public userClaimedBNB;
    uint256 public totalClaimedBNB;

    mapping(address => uint256) private userreinvested;
    uint256 private totalreinvested;

    // trace gas fees distribution
    uint256 private totalgasfeesdistributed;
    mapping(address => uint256) private userrecievedgasfees;

    address private deadAddress;

    address[] private _excluded;

    uint256 private MAX;
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    IPancakeRouter02 private pancakeRouter;
    address private pancakePair;

    bool private _inSwapAndLiquify;

    uint256 private daySeconds;

    struct WalletAllowance {
        uint256 timestamp;
        uint256 amount;
    }

    mapping(address => WalletAllowance) userWalletAllowance;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event ClaimBNBSuccessfully(
        address recipient,
        uint256 ethReceived,
        uint256 nextAvailableClaimDate
    );

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    constructor() {}

    mapping(address => bool) isBlacklisted;
    
    function getPancakePair() public view returns (address) {
        return pancakePair;
    }

    function getPancakeRouter() public view returns (IPancakeRouter02) {
        return pancakeRouter;
    }

    function name() public view returns (string memory) {
        return _name;
    }
    
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return _rOwned[account] / getRate();
    }

    function transfer(address recipient, uint256 amount) public override returns (bool){
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256){
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool){
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function isExcludedFromReflections(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }
    
    
    function excludeFromReflections(address account) external onlyOwner {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Pancake router.');
        require(_excluded.length < 100, "Err");
        require(!_isExcluded[account], "Err");
        if (_rOwned[account] > 0) {
            _tOwned[account] = _rOwned[account] / getRate();
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReflections(address account) external onlyOwner {
        require(_isExcluded[account], "Err");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    

    function includeExcludeFromFee(address account, bool _enable) external onlyOwner {
        _isExcludedFromFee[account] = _enable;
    }

    //to receive BNB from pancakeRouter when swapping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee; 
        _tFeeTotal = _tFeeTotal + tFee; 
    }

    function getRate() public view returns (uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            rSupply = rSupply - _rOwned[_excluded[i]]; 
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return _rTotal / _tTotal;
        return rSupply / tSupply; 
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 rLiquidity = tLiquidity * getRate();
        _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] + tLiquidity;
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0) && spender != address(0), "Err");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0) && to != address(0), "Err");
        require(amount > 0, "Err");
            //reinvest
            if (to == reinvestWallet && pairAddresses[from]) {
                uint256 rAmount = amount * getRate();
                _rOwned[reinvestWallet] += rAmount;
                _rOwned[from] -= rAmount; 
            } else if (poolAddresses[to] || poolAddresses[from]) {
                topUpClaimCycleAfterTransfer(from, to, amount);
                uint256 rAmount = amount * getRate();
                _rOwned[to] += rAmount;
                _rOwned[from] -= rAmount;
                if (_isExcluded[from]) {
                    _tOwned[from] -= amount;
                } 
                if (_isExcluded[to]) {
                    _tOwned[to] += amount;
                }	     
                emit Transfer(from, to, amount);
            } else {
                //indicates if fee should be deducted from transfer
                bool takeFee = !(
                    _isExcludedFromFee[from] ||
                    _isExcludedFromFee[to] ||
                    reflectionFeesDisabled
                );
        
                if (!(vbAddresses[to] || vbAddresses[from]))
                {
                    // take sell fee
                    if (
                        pairAddresses[to] &&
                        from != address(this) &&
                        from != owner()
                    ) {
                        /*
                        *   "If you can't hold, you won't be rich" - CZ
                        */
                        ensureMaxTxAmount(from, to, amount);          
                        
                        if (!_inSwapAndLiquify) {
                            swapAndLiquify(from, to);
                        }
                    }              
                    // take buy fee
                    else if (
                        pairAddresses[from] && to != address(this) && to != owner()
                    ) {
                        uint256 tBonusTokens = Utils.getBonus(to, HodlHands, amount, HHBonus);
                        if (tBonusTokens > 0) {
                            uint256 rBonusTokens = tBonusTokens * getRate();
                            _rOwned[address(this)] -= rBonusTokens;
                            _rOwned[to] += rBonusTokens;

                            if (_isExcluded[to]) _tOwned[to] += tBonusTokens;
                            emit Transfer(address(this),to,tBonusTokens);
                        }  
                    }
                }
                //transfer amount, it will take tax, burn, liquidity fee
                _tokenTransfer(from, to, amount, takeFee);
            }      
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) {
            _taxFee = 0;
            _liquidityFee = 0;
        } else {
             _taxFee = 10;
            _liquidityFee = 40;
        }

        // top up claim cycle for recipient and sender
        topUpClaimCycleAfterTransfer(sender, recipient, amount);

        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = Utils._getValues(amount, getRate(), _taxFee, _liquidityFee);
        _rOwned[sender] = _rOwned[sender] - rAmount; 
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount; 

        if (_isExcluded[sender]) {
            _tOwned[sender] = _tOwned[sender] - amount; 
        } 
        if (_isExcluded[recipient]) {
            _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        } 

        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);

    }

    function getMaxTxAmount() public view returns (uint256) {
        return _maxTxAmount;
    }

    // Innovation for protocol by HODL Team
    uint256 public rewardCycleBlock;
    uint256 public maxAmountToSell;
    uint256 public threshHoldTopUpRate;
    uint256 private _maxTxAmount;
    uint256 public bnbStackingLimit;
    mapping(address => uint256) public nextAvailableClaimDate;
    bool public swapAndLiquifyEnabled;
    uint256 private reserve_3;
    uint256 private rateCorrection;

    bool public reflectionFeesDisabled;

    uint256 private _taxFee;
    uint256 private reserve_4;

    // Lottery removed
    uint256 private LotteryThreshold;
    uint256 private totalLotteryTickets;
    uint256 private LotteryWinningChance;
    uint256 private pendingLotteryTickets;
    uint256 private ticketsToDraw;
    uint256 private AddCommunityTicket;
    uint256 private communityTicketsWinningChance;
    uint256 private burnPercentage;
    uint256 private requestedRandomNumbers;
    //Chainlink disabled
    uint256 private callbackGasLimit;
    uint256 private requestConfirmations;
    uint256 private s_subscriptionId;

    // Tax variables removed
    uint256 private reserve_5;
    uint256 private reserve_6;
    uint256 private reserve_7;

    uint256 public claimBNBLimit;
    uint256 public reinvestLimit;
    uint256 private reserve_1;

    address private reserve_address;
    address public HodlHands;
    address private reserve_address_2;
    address public stackingWallet;
    
    uint256 private _liquidityFee;
    uint256 private reserve_8;

    uint256 public busdToSell; 
    uint256 public minTokenNumberUpperlimit;

    uint256 public rewardHardcap;

    //removed
    Taxes private taxes;
    
    struct Taxes {
        uint256 bnbReward;
        uint256 liquidity;
        uint256 company;
        uint256 reflection;
        uint256 lottery;
    }

    uint256 private reserve_9;
    uint256 private reserve_10;

    address public triggerwallet;

    mapping(address => bool) public pairAddresses;

    address public HodlMasterChef;

    mapping(address => uint256) private firstBuyTimeStamp;

    mapping(address => HODLStruct.stacking) public rewardStacking;
    bool public stackingEnabled;

    mapping(address => uint256) private stackingRate;

    //Lottery removed
    bool private reserve_bool_1;
    HODLStruct.LastLotteryWin private    LastLotteryWinner;
    HODLStruct.LotteryTicket[] private   _lotteryTickets;
    mapping(address => uint[]) private   TicketNumbers;

    //Chainlink removed
    VRFCoordinatorV2Interface COORDINATOR;
    address private reserve_vrfCoordinator;
    bytes32 private reserve_keyHash;

    //Bonus HH
    HODLStruct.HHBonus[5] public HHBonus;

    //Path
    IPancakeRouter02 public HODLXRouter = IPancakeRouter02(0xd4dd4bf4abe7454a1C04199321AAeFD85A7beAE1);  
    address public HODLXToken;

    mapping(address => mapping(address => uint256)) private userreinvestedCustomToken;
    mapping(address => uint256) public totalreinvestedCustomToken;

    address public reinvestWallet;

    //Pool addresses -> No tax, less checks on transfers
    mapping(address => bool) public poolAddresses;

    //Bonus days on 100% reinvest in HODL
    uint256 public HODLreinvestBonusCycle;

    //vbWallets
    mapping(address => bool) private vbAddresses;

    //Events
    event changeValue(string tag, uint256 _value);
    event changeEnable(string tag, bool _enable);
    event changeAddress(string tag, address _address);

    event StartStacking(
        address sender,
        uint256 amount
    );
    event LotteryWin(address _wallet, uint256 amount);
    event CommunityWin(uint256 amount);
    
    /*
    *   "Rome was not built in a day" - John Heywood
    */
    function calculateBNBReward(address ofAddress) external view returns (uint256){        
        return Utils.calculateBNBReward(
                balanceOf(address(ofAddress)),
                address(this).balance,
                _tTotal - (_rOwned[deadAddress] / getRate()) - balanceOf(address(pancakePair)), 
                rewardHardcap
            );
    }

    /** @dev Function to claim the rewards.
    *   First calculate the rewards with checking rewardhardcap and current pool
    *   Depending on user selected percentage pay reward in bnb or reinvest in tokens
    *
    *   "Keep building. That's how you prove them wrong." - David Gokhstein     
    */
    function redeemRewards(uint256 perc, address token) external isHuman nonReentrant {

        require(nextAvailableClaimDate[msg.sender] <= block.timestamp, "Error: too early");
        require(balanceOf(msg.sender) > 0, "Error: no Hodl");

        uint256 totalsupply = _tTotal - (_rOwned[deadAddress] / getRate()) - balanceOf(address(pancakePair));  
        uint256 currentBNBPool = address(this).balance;

        uint256 reward = currentBNBPool > rewardHardcap ? rewardHardcap * balanceOf(msg.sender) / totalsupply : currentBNBPool * balanceOf(msg.sender) / totalsupply; 

        uint256 rewardreinvest;
        uint256 rewardBNB;

        uint256 bonusCycle = (perc == 0 && token == address(this)) ? HODLreinvestBonusCycle : 0;

        if (perc == 100) {
            require(reward > claimBNBLimit, "Reward below gas fee");
            rewardBNB = reward;
        } else if (perc == 0) {     
            rewardreinvest = reward;
        } else {
            rewardBNB = reward * perc / 100;  
            rewardreinvest = reward - rewardBNB;
        }

        // BNB REINVEST
        if (perc < 100) {
            require(token == address(this) || token == HODLXToken, "Err");
            require(reward > reinvestLimit, "Reward below gas fee");
            bool hodlx = token == HODLXToken;

            IPancakeRouter02 Router = hodlx ? HODLXRouter : pancakeRouter;
            
            address[] memory path = new address[](2);
            path[0] = Router.WETH();
            path[1] = hodlx ? HODLXToken : address(this);

            // Update Stats
            uint256[] memory expectedtoken = Router.getAmountsOut(rewardreinvest, path);
            userreinvestedCustomToken[token][msg.sender] += expectedtoken[1];
            totalreinvestedCustomToken[token] += expectedtoken[1];

            //Swap Tokens
            Router.swapExactETHForTokens{
                    value: rewardreinvest
                }(
                    0, // accept any amount of BNB
                    path,
                    hodlx ? msg.sender : reinvestWallet,
                    block.timestamp + 360
                );
            
            if (!hodlx) {
                uint256 rExpectedtoken = expectedtoken[1] * getRate();
                _rOwned[reinvestWallet] -= rExpectedtoken;
                _rOwned[msg.sender] += rExpectedtoken;
                emit Transfer(pancakePair, msg.sender, expectedtoken[1]); 
            }
        }

        // BNB CLAIM
        if (rewardBNB > 0) {
            // send bnb to user
            (bool success, ) = address(msg.sender).call{value: rewardBNB}("");
            require(success, "Err");

            // update claimed rewards
            userClaimedBNB[msg.sender] += rewardBNB;
            totalClaimedBNB += rewardBNB;
        }

        // update rewardCycleBlock
        nextAvailableClaimDate[msg.sender] = block.timestamp + rewardCycleBlock - bonusCycle;
        emit ClaimBNBSuccessfully(msg.sender,reward,nextAvailableClaimDate[msg.sender]);
    }

    /* @dev Top up next claim date of sender and recipient. 
    */
    function topUpClaimCycleAfterTransfer(address _sender, address _recipient, uint256 amount) private {
        //_recipient
        uint256 currentBalance = balanceOf(_recipient);
        if ((_recipient == owner() && nextAvailableClaimDate[_recipient] == 0) || currentBalance == 0 || _sender == HodlMasterChef) {
                nextAvailableClaimDate[_recipient] = block.timestamp + rewardCycleBlock;
        } else {
            nextAvailableClaimDate[_recipient] += Utils.calculateTopUpClaim(
                                                currentBalance,
                                                rewardCycleBlock,
                                                threshHoldTopUpRate,
                                                amount);
            if (nextAvailableClaimDate[_recipient] > block.timestamp + rewardCycleBlock) {
                nextAvailableClaimDate[_recipient] = block.timestamp + rewardCycleBlock;
            }
        }

        //sender
        if (_recipient != HodlMasterChef) {
            currentBalance = balanceOf(_sender);
            if ((_sender == owner() && nextAvailableClaimDate[_sender] == 0) || currentBalance == 0) {
                    nextAvailableClaimDate[_sender] = block.timestamp + rewardCycleBlock;
            } else {
                nextAvailableClaimDate[_sender] += Utils.calculateTopUpClaim(
                                                    currentBalance,
                                                    rewardCycleBlock,
                                                    threshHoldTopUpRate,
                                                    amount);
                if (nextAvailableClaimDate[_sender] > block.timestamp + rewardCycleBlock) {
                    nextAvailableClaimDate[_sender] = block.timestamp + rewardCycleBlock;
                }                                     
            }
        }
    }

    /* @dev Function to ensure that in the last 24h not more tokens selled 
    *   than defined in _maxTxAmount
    */
    function ensureMaxTxAmount(address from, address to, uint256 amount) private {
        if (
            _isExcludedFromMaxTx[from] == false && // default will be false
            _isExcludedFromMaxTx[to] == false // default will be false
        ) {
                WalletAllowance storage wallet = userWalletAllowance[from];

                if (block.timestamp > wallet.timestamp + daySeconds) { 
                    wallet.timestamp = 0;
                    wallet.amount = 0;
                }

                uint256 totalAmount = wallet.amount + amount;

                require(
                    totalAmount <= _maxTxAmount,
                    "Error"
                );

                if (wallet.timestamp == 0) {
                    wallet.timestamp = block.timestamp;
                }

                wallet.amount = totalAmount;
        }
    }

    /* @dev Function that swaps tokens from the contract for bnb
    *   Bnb is split up due to taxes and send to the specified wallets
    *
    *       "They talk, we build" - Josh from StaySAFU
    */
    function swapAndLiquify(address from, address to) private lockTheSwap {

        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 initialBalance = address(this).balance;

        if (contractTokenBalance >= minTokenNumberUpperlimit &&
            initialBalance <= rewardHardcap &&
            swapAndLiquifyEnabled &&
            from != pancakePair &&
            !(from == address(this) && to == address(pancakePair))
            ) { 
                Utils.swapTokensForEth(address(pancakeRouter), getAmountToSell());  
            }
    }

    /* @dev Same as swapAndLiquify but manually called by the owner
    *   or the triggerWallet.
    */
    function triggerSwapAndLiquify() external lockTheSwap {
        require(((_msgSender() == address(triggerwallet)) || (_msgSender() == owner())) && swapAndLiquifyEnabled, "Error");
        Utils.swapTokensForEth(address(pancakeRouter), getAmountToSell());
    }

    /*  @dev Enable/Disable if address is a HODL Pair address
    */
    function updatePairAddress(address _pairAddress, bool _enable) external onlyOwner {
        pairAddresses[_pairAddress] = _enable;
    }

    function updatePoolAddress(address _poolAddress, bool _enable) external onlyOwner {
        poolAddresses[_poolAddress] = _enable;
    }
    
    /*  @dev Function to start rward stacking. the whole tokens (minus 1) are sent to the
    *   stacking wallet. While stacking is enabled the bnb reward is accumulated.
    *   Once the user stops stacking the amount it sent back plus the accumulated reward.
    *
    *       "HODL Bears to ride Bulls" - Adam Roberts
    */
    function startStacking() external {
        
        uint96 balance = uint96(balanceOf(msg.sender)-1E9);

        require(stackingEnabled && !rewardStacking[msg.sender].enabled, "Err");
        require(nextAvailableClaimDate[msg.sender] <= block.timestamp, "Error: too early");
        require(balance > 15000000000000000, "Err");

        rewardStacking[msg.sender] = HODLStruct.stacking(
            true, 
            uint64(rewardCycleBlock), 
            uint64(block.timestamp), 
            uint96(bnbStackingLimit), 
            uint96(balance), 
            uint96(rewardHardcap));

        uint256 currentRate = getRate();
        stackingRate[msg.sender] = currentRate;

        uint256 rBalance = balance * currentRate;
        _rOwned[msg.sender] -= rBalance;
        _rOwned[stackingWallet] += rBalance;
        emit Transfer(msg.sender, stackingWallet, balance);
        emit StartStacking(msg.sender, balance);
    }
    
    /*  @dev Calculate the amount of stacked reward
    */
    function getStacked(address _address) public view returns (uint256) {
        HODLStruct.stacking memory tmpStack =  rewardStacking[_address];
        if (tmpStack.enabled) {
            return Utils.calcStacked(tmpStack, _tTotal - (_rOwned[deadAddress] / getRate()) - balanceOf(address(pancakePair)), getRate(), stackingRate[msg.sender]);
        }
        return 0;
    }

    /* @dev Technically same function as 'redeemReward' but with stacked amount and 
    *  stacked claim cycles. Reward is calculated with function getStacked.
    *   
    *   "Max pain before gain in crypto" - Travladd
    *
    *   Reflections are added before amount is sent back to the user
    */
    function stopStackingAndClaim(uint256 perc, address token) external nonReentrant {

        HODLStruct.stacking memory tmpstacking = rewardStacking[msg.sender];

        require(tmpstacking.enabled, "Err");
        uint256 amount;
        uint256 rewardBNB;
        uint256 rewardreinvest;
        uint256 reward = getStacked(msg.sender);
        uint256 currentRate =  getRate();

        uint256 bonusCycle = (perc == 0 && token == address(this)) ? HODLreinvestBonusCycle : 0;

        if (perc == 100) {
            rewardBNB = reward;
        } else if (perc == 0) {     
            rewardreinvest = reward;
        } else {
            rewardBNB = reward * perc / 100;
            rewardreinvest = reward - rewardBNB;
        }

        // BNB REINVEST
        if (perc < 100) {
            require(token == address(this) || token == HODLXToken, "Err");
            bool hodlx = token == HODLXToken;

            IPancakeRouter02 Router = hodlx ? HODLXRouter : pancakeRouter;
            
            address[] memory path = new address[](2);
            path[0] = Router.WETH();
            path[1] = hodlx ? HODLXToken : address(this);

            // Update Stats
            uint256[] memory expectedtoken = Router.getAmountsOut(rewardreinvest, path);
            userreinvestedCustomToken[token][msg.sender] += expectedtoken[1];
            totalreinvestedCustomToken[token] += expectedtoken[1];

            //Swap Tokens
            Router.swapExactETHForTokens{
                    value: rewardreinvest
                }(
                    0, // accept any amount of BNB
                    path,
                    hodlx ? msg.sender : reinvestWallet,
                    block.timestamp + 360
                );

            if (!hodlx) {
                uint256 rExpectedtoken = expectedtoken[1] * getRate();
                _rOwned[reinvestWallet] -= rExpectedtoken;
                _rOwned[msg.sender] += rExpectedtoken;
                emit Transfer(pancakePair, msg.sender, expectedtoken[1]); 
            }

        }

        // BNB CLAIM
        if (rewardBNB > 0) {
            // send bnb to user
            (bool success, ) = address(msg.sender).call{value: rewardBNB}("");
            require(success, "Err");

            // update claimed rewards
            userClaimedBNB[msg.sender] += rewardBNB;
            totalClaimedBNB += rewardBNB;
        }

        uint256 rate = stackingRate[msg.sender];

        if (rate > 0)
        {
            amount = tmpstacking.amount * rate / currentRate;
        } else {
            amount = tmpstacking.amount;
        }

        uint256 rAmount = amount * currentRate;
        _rOwned[msg.sender] += rAmount;
        _rOwned[stackingWallet] -= rAmount;
        emit Transfer(stackingWallet, msg.sender, amount);

        HODLStruct.stacking memory tmpStack;
        rewardStacking[msg.sender] = tmpStack;

        // update rewardCycleBlock
        nextAvailableClaimDate[msg.sender] = block.timestamp + rewardCycleBlock - bonusCycle;
        emit ClaimBNBSuccessfully(msg.sender,reward,nextAvailableClaimDate[msg.sender]);
    }

    /* @dev Change threshold and bonus-% for holding HH NFTs
    */
    function changeHHBonus(uint8 layer, uint16 _threshold, uint16 _bonus) external onlyOwner {
        HHBonus[layer].threshold = _threshold;
        HHBonus[layer].bonus = _bonus;
    }

    function getUserReinvested(address _wallet, address _token) external view returns(uint256) {
        uint256 reinvested = userreinvestedCustomToken[_token][_wallet];
        if (_token == address(this)) reinvested += userreinvested[_wallet];
        return reinvested;
    }

    function changeBUSDvalueToSell(uint256 _value) external onlyOwner {
        busdToSell = _value * 1E18;
        emit changeValue("busdToSell", _value);
    }

    function changeMaxAmountToSell(uint256 _value) external onlyOwner {
        require(maxAmountToSell < minTokenNumberUpperlimit);
        maxAmountToSell = _value;
        emit changeValue("maxAmountToSell", _value);
    }
    
    /* @dev Get HODL amount for sell bot
    */
    function getAmountToSell() private view returns(uint256) {
        uint256 tokenAmount;
        address[] memory path = new address[](3);
        path[0] = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; //BUSD
        path[1] = pancakeRouter.WETH();
        path[2] = address(this);
        tokenAmount = pancakeRouter.getAmountsOut(busdToSell, path)[2];
        return tokenAmount > maxAmountToSell ? maxAmountToSell : tokenAmount;
    }

    function changeHODLXRouter(address _router) external onlyOwner {
        HODLXRouter = IPancakeRouter02(_router);
        emit changeAddress("HODLXRouter", _router);
    }

}

library HODLStruct {
    struct stacking {
        bool enabled;
        uint64 cycle;
        uint64 tsStartStacking;
        uint96 stackingLimit;
        uint96 amount;
        uint96 hardcap;   
    }
 
    struct LotteryTicket {
        address Wallet;
        uint16 Number;
        bool Won;  
        uint256 PossibleWinAmount;
        uint256 TimeStamp; 
    }

    struct LastLotteryWin {
        address Winner;
        uint256 Amount;
        uint256 TimeStamp;
    }

    struct HHBonus {
        uint16 threshold;
        uint16 bonus;
    }
}