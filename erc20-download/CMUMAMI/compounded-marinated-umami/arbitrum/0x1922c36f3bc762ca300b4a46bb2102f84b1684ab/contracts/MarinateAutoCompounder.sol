// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//                                                                            //
//                              #@@@@@@@@@@@@&,                               //
//                      .@@@@@   .@@@@@@@@@@@@@@@@@@@*                        //
//                  %@@@,    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@                    //
//               @@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                 //
//             @@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@               //
//           *@@@#    .@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@             //
//          *@@@%    &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            //
//          @@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           //
//          @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           //
//                                                                            //
//          (@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,           //
//          (@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,           //
//                                                                            //
//          @@@@@   @@@@@@@@@   @@@@@@@@@   @@@@@@@@@   @@@@@@@@@             //
//            &@@@@@@@    #@@@@@@@.   ,@@@@@@@,   .@@@@@@@/    @@@@           //
//                                                                            //
//          @@@@@      @@@%    *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           //
//          @@@@@      @@@@    %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           //
//          .@@@@      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            //
//            @@@@@  &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@             //
//                (&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&(                 //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// Libraries
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";
import { IMarinateV2 } from "./interfaces/IMarinateV2.sol";

/// @title Umami Marinate Auto-Compounder
contract MarinateAutoCompounder is ERC20, AccessControl, IStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /************************************************
     *  STORAGE
     ***********************************************/

    /// @notice total deposited mUMAMI
    uint256 public totalDeposits;

    /// @notice the destination for admin fees
    address public feeDestination;

    /// @notice the deposit token for the autocompounder
    IERC20 public depositToken;

    /// @notice the univ3 router
    ISwapRouter public router;

    /// @notice reward tokens recieved from marinate
    address[] public rewardTokens;

    /// @notice swap routes for the reward tokens
    bytes[] public routes;

    /// @notice if the token is an approved reward token
    mapping(address => bool) public isRewardToken;

    /// @notice marinateV2 contract address
    IMarinateV2 public marinateContract;

    /// @notice minimum amount of tokens to reinvest
    uint256 public MIN_TOKENS_TO_REINVEST;

    /// @notice  reinvest reward
    uint256 public REINVEST_REWARD_BIPS;

    /// @notice admin fee taken when reinvested
    uint256 public ADMIN_FEE_BIPS;

    /************************************************
     *  CONSTANTS
     ***********************************************/

    /// @notice WETH token
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    /// @notice UMAMI token
    address constant UMAMI = 0x1622bF67e6e5747b81866fE0b85178a93C7F86e3;

    /// @notice divisor for percentage calculations
    uint256 private constant BIPS_DIVISOR = 10000;

    /// @notice admin role hash
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /************************************************
     *  EVENTS
     ***********************************************/

    event Claim(address indexed account, uint256 amount);
    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);
    event Reinvest(uint256 newTotalDeposits, uint256 newTotalSupply);
    event Recovered(address token, uint256 amount);
    event UpdateAdminFee(uint256 oldValue, uint256 newValue);
    event UpdateReinvestReward(uint256 oldValue, uint256 newValue);
    event UpdateMinTokensToReinvest(uint256 oldValue, uint256 newValue);
    event UpdateWithdrawFee(uint256 oldValue, uint256 newValue);
    event UpdateRequireReinvestBeforeDeposit(bool newValue);
    event UpdateMinTokensToReinvestBeforeDeposit(uint256 oldValue, uint256 newValue);

    /************************************************
     *  CONSTRUCTOR
     ***********************************************/

    constructor(
        string memory _name,
        string memory _symbol,
        address _depositToken,
        address _marinateContract,
        address _router
    ) ERC20(_name, _symbol) {
        depositToken = IERC20(_depositToken);
        marinateContract = IMarinateV2(_marinateContract);
        router = ISwapRouter(_router);
        rewardTokens = [WETH];
        isRewardToken[WETH] = true;
        uint24 poolFee = 10000;
        routes = [abi.encodePacked(WETH, poolFee, UMAMI)];
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        feeDestination = msg.sender;
        REINVEST_REWARD_BIPS = 50;
        MIN_TOKENS_TO_REINVEST = 10000;
        ADMIN_FEE_BIPS = 300;
    }

    /************************************************
     *  DEPOSIT & WITHDRAW
     ***********************************************/

    /**
     * @notice Deposit tokens to receive receipt tokens
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external override nonReentrant {
        _deposit(amount);
    }

    /**
     * @notice handle deposit logic
     * @param amount Amount of tokens to deposit
     */
    function _deposit(uint256 amount) internal {
        require(totalDeposits >= totalSupply(), "deposit failed");
        require(depositToken.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        _mint(msg.sender, getSharesForDepositTokens(amount));
        totalDeposits = totalDeposits + amount;
        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw LP tokens by redeeming receipt tokens
     * @param amount Amount of receipt tokens to redeem
     */
    function withdraw(uint256 amount) external override nonReentrant {
        require(balanceOf(msg.sender) >= amount, "insufficent balance to withdraw");
        uint256 depositTokenAmount = getDepositTokensForShares(amount);
        if (depositTokenAmount > 0) {
            require(depositToken.transfer(msg.sender, depositTokenAmount), "transfer failed");
            _burn(msg.sender, amount);
            totalDeposits = totalDeposits - depositTokenAmount;
            emit Withdraw(msg.sender, depositTokenAmount);
        }
    }

    /************************************************
     *  COMPOUND
     ***********************************************/

    /**
     * @notice Reinvest rewards from staking contract to deposit tokens
     * @dev This external function requires minimum tokens to be met
     */
    function reinvest() external override onlyEOA {
        uint256 unclaimedRewards = checkReward();
        require(unclaimedRewards >= MIN_TOKENS_TO_REINVEST, "MIN_TOKENS_TO_REINVEST");
        _reinvest();
    }

    /**
     * @notice Reinvest rewards from staking contract to deposit tokens
     * @dev This internal function does not require mininmum tokens to be met
     */
    function _reinvest() internal {
        marinateContract.claimRewards();
        uint256 umamiClaimed = convertRewardTokensToDepositTokens();
        require(umamiClaimed > 0, "No rewards to reinvest");

        uint256 adminFee = (umamiClaimed * ADMIN_FEE_BIPS) / BIPS_DIVISOR;
        if (adminFee > 0) {
            require(IERC20(UMAMI).transfer(feeDestination, adminFee), "admin fee transfer failed");
        }

        uint256 reinvestFee = (umamiClaimed * REINVEST_REWARD_BIPS) / BIPS_DIVISOR;
        if (reinvestFee > 0) {
            require(IERC20(UMAMI).transfer(msg.sender, reinvestFee), "reinvest fee transfer failed");
        }

        uint256 toRedeposit = (umamiClaimed - adminFee) - reinvestFee;
        _stakeDepositTokens(toRedeposit);
        totalDeposits = totalDeposits + toRedeposit;

        emit Claim(msg.sender, umamiClaimed);
        emit Reinvest(totalDeposits, totalSupply());
    }

    /**
     * @notice Converts all reward tokens to deposit tokens
     * @dev Always converts through router; there are no price checks enabled
     */
    function convertRewardTokensToDepositTokens() private returns (uint256) {
        uint256 totalUmamiReturned = 0;
        // loop over reward tokens
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 tokenBalance = IERC20(rewardTokens[i]).balanceOf(address(this));
            if (tokenBalance > MIN_TOKENS_TO_REINVEST) {
                // swap to umami
                ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
                    path: routes[i],
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: tokenBalance,
                    amountOutMinimum: 0
                });
                // The call to `exactInput` executes the swap.
                totalUmamiReturned += router.exactInput(params);
            }
        }
        return totalUmamiReturned;
    }

    /**
     * @notice Stakes deposit tokens in Staking Contract
     * @param amount deposit tokens to stake
     */
    function _stakeDepositTokens(uint256 amount) internal {
        require(amount > 0, "amount too low");
        marinateContract.stake(amount);
    }

    /**
     * @notice Max reward token balance that can be reinvested
     * @dev Staking rewards accurue to contract on each deposit/withdrawal
     * @return Unclaimed rewards, plus contract balance
     */
    function checkReward() public returns (uint256) {
        uint256 maxRewards = 0;
        uint256 tokenTotalRewards;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            tokenTotalRewards =
                marinateContract.getAvailableTokenRewards(address(this), rewardTokens[i]) +
                IERC20(rewardTokens[i]).balanceOf(address(this));
            if (tokenTotalRewards > maxRewards) {
                maxRewards = tokenTotalRewards;
            }
        }
        return maxRewards;
    }

    /************************************************
     *  MUTATORS
     ***********************************************/

    /**
     * @notice add a reward token
     * @param rewardToken the address of the token to add
     * @param swapRoute the swap route to take when reinvesting the token
     */
    function addRewardToken(address rewardToken, bytes calldata swapRoute) external onlyAdmin {
        require(!isRewardToken[rewardToken], "Reward token exists");
        isRewardToken[rewardToken] = true;
        rewardTokens.push(rewardToken);
        routes.push(swapRoute);
    }

    /**
     * @notice remove a reward token
     * @param rewardToken the address of the token to remove
     */
    function removeRewardToken(address rewardToken) public onlyAdmin {
        require(isRewardToken[rewardToken], "Reward token !exists");
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == rewardToken) {
                rewardTokens[i] = rewardTokens[rewardTokens.length - 1];
                routes[i] = routes[routes.length - 1];
                rewardTokens.pop();
                routes.pop();
                isRewardToken[rewardToken] = false;
            }
        }
    }

    /**
     * @notice set desination for admin fees generated by this pool
     * @param newDestination the address to send fees to
     */
    function setFeeDestination(address newDestination) public onlyAdmin {
        feeDestination = newDestination;
    }

    /**
     * @notice Update reinvest minimum threshold for external callers
     * @param newValue min threshold in wei
     */
    function updateMinTokensToReinvest(uint256 newValue) external onlyAdmin {
        emit UpdateMinTokensToReinvest(MIN_TOKENS_TO_REINVEST, newValue);
        MIN_TOKENS_TO_REINVEST = newValue;
    }

    /**
     * @notice Update admin fee
     * @dev Total fees cannot be greater than BIPS_DIVISOR (max 5%)
     * @param newValue specified in BIPS
     */
    function updateAdminFee(uint256 newValue) external onlyAdmin {
        require(newValue + REINVEST_REWARD_BIPS <= BIPS_DIVISOR / 20, "admin fee too high");
        emit UpdateAdminFee(ADMIN_FEE_BIPS, newValue);
        ADMIN_FEE_BIPS = newValue;
    }

    /**
     * @notice Update reinvest reward
     * @dev Total fees cannot be greater than BIPS_DIVISOR (max 5%)
     * @param newValue specified in BIPS
     */
    function updateReinvestReward(uint256 newValue) external onlyAdmin {
        require(newValue + ADMIN_FEE_BIPS <= BIPS_DIVISOR / 20, "reinvest reward too high");
        emit UpdateReinvestReward(REINVEST_REWARD_BIPS, newValue);
        REINVEST_REWARD_BIPS = newValue;
    }

    /************************************************
     *  VIEWS
     ***********************************************/

    /**
     * @notice Calculate receipt tokens for a given amount of deposit tokens
     * @dev If contract is empty, use 1:1 ratio
     * @dev Could return zero shares for very low amounts of deposit tokens
     * @param amount deposit tokens
     * @return receipt tokens
     */
    function getSharesForDepositTokens(uint256 amount) public view returns (uint256) {
        if ((totalSupply() * totalDeposits) == 0) {
            return amount;
        }
        return (amount * totalSupply()) / totalDeposits;
    }

    /**
     * @notice Calculate deposit tokens for a given amount of receipt tokens
     * @param amount receipt tokens
     * @return deposit tokens
     */
    function getDepositTokensForShares(uint256 amount) public view returns (uint256) {
        if ((totalSupply() * totalDeposits) == 0) {
            return 0;
        }
        return (amount * totalDeposits) / totalSupply();
    }

    /**
     * @notice Returns length of reward tokens
     * @return length of reward tokens
     */
    function rewardTokensLength() public view returns (uint256) {
        return rewardTokens.length;
    }

    /************************************************
     *  ADMIN
     ***********************************************/

    /**
     * @notice Recover ether from contract (should never be any in it)
     * @param amount amount
     */
    function recoverETH(uint256 amount) external onlyAdmin {
        require(amount > 0, "amount too low");
        payable(msg.sender).transfer(amount);
        emit Recovered(address(0), amount);
    }

    /**
     * @notice migrate a token to a different address
     * @param token the token address
     * @param destination the token destination
     * @param amount the token amount
     */
    function migrateToken(
        address token,
        address destination,
        uint256 amount
    ) external onlyAdmin {
        uint256 total = 0;
        if (amount == 0) {
            total = IERC20(token).balanceOf(address(this));
        } else {
            total = amount;
        }
        IERC20(token).safeTransfer(destination, total);
    }

    /**
     * @notice Approve tokens for use in Strategy
     * @dev Restricted to avoid griefing attacks
     */
    function setAllowances() public onlyAdmin {
        IERC20(UMAMI).approve(address(marinateContract), IERC20(UMAMI).totalSupply());
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20(rewardTokens[i]).approve(address(router), IERC20(rewardTokens[i]).totalSupply());
        }
    }

    /**
     * @notice Revoke token allowance
     * @dev Restricted to avoid griefing attacks
     * @param token address
     * @param spender address
     */
    function revokeAllowance(address token, address spender) external onlyAdmin {
        require(IERC20(token).approve(spender, 0));
    }

    /************************************************
     *  MODIFIERS
     ***********************************************/

    /**
     * @dev Throws if called by smart contract
     */
    modifier onlyEOA() {
        require(tx.origin == msg.sender, "onlyEOA");
        _;
    }

    /**
     * @dev Throws if not admin role
     */
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    /************************************************
     *  ERC20 OVERRIDES
     ***********************************************/

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
}
