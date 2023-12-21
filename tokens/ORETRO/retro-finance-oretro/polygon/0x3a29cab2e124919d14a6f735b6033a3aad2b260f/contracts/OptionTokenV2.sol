// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IRetro} from "./interfaces/IRetro.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IUniswapV3Twap} from "./interfaces/IUniswapV3Twap.sol";
import {IOptionFeeDistributor} from "./interfaces/IOptionFeeDistributor.sol";

/// @title Option Token
/// @notice Option token representing the right to purchase the underlying token
/// at TWAP reduced rate. Similar to call options but with a variable strike
/// price that's always at a certain discount to the market price.
/// @dev Assumes the underlying token and the payment token both use 18 decimals and revert on
// failure to transfer.

contract OptionTokenV2 is ERC20, AccessControl {
    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------
    uint256 public constant MAX_DISCOUNT = 100; // 100%
    uint256 public constant MIN_DISCOUNT = 0; // 0%
    uint256 public constant MAX_TWAP_SECONDS = 86400; // 2 days
    uint256 public constant FULL_LOCK = 2 * 365 * 86400; // 2 years

    /// -----------------------------------------------------------------------
    /// Roles
    /// -----------------------------------------------------------------------
    /// @dev The identifier of the role which maintains other roles and settings
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    /// @dev The identifier of the role which is allowed to mint options token
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");

    /// @dev The identifier of the role which allows accounts to pause execrcising options
    /// in case of emergency
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER");

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------
    error OptionToken_PastDeadline();
    error OptionToken_NoAdminRole();
    error OptionToken_NoMinterRole();
    error OptionToken_NoPauserRole();
    error OptionToken_SlippageTooHigh();
    error OptionToken_InvalidDiscount();
    error OptionToken_Paused();
    error OptionToken_InvalidTwapSeconds();
    error OptionToken_IncorrectPairToken();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Exercise(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 paymentAmount
    );
    event ExerciseVe(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 paymentAmount,
        uint256 nftId
    );
    event SetTwapOracleAndPaymentToken(
        IUniswapV3Twap indexed _twapOracle,
        address indexed _paymentToken
    );
    event SetFeeDistributor(IOptionFeeDistributor indexed newFeeDistributor);
    event SetDiscount(uint256 discount);
    event SetVeDiscount(uint256 veDiscount);
    event PauseStateChanged(bool isPaused);
    event SetTwapSeconds(uint32 twapSeconds);

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice The token paid by the options token holder during redemption
    ERC20 public paymentToken;

    /// @notice The underlying token purchased during redemption
    ERC20 public immutable underlyingToken;

    /// @notice The voting escrow for locking FLOW to veFLOR
    address public votingEscrow;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice The oracle contract that provides the current TWAP price to purchase
    /// the underlying token while exercising options (the strike price)
    IUniswapV3Twap public twapOracle;

    /// @notice The contract that receives the payment tokens when options are exercised
    IOptionFeeDistributor public feeDistributor;

    /// @notice the discount given during exercising. 30 = user pays 30%
    uint256 public discount;

    /// @notice the further discount for locking to veFLOW
    uint256 public veDiscount;

    /// @notice controls the duration of the twap used to calculate the strike price
    // each point represents 30 minutes. 4 points = 2 hours
    uint32 public twapSeconds = 60 * 30 * 4;

    /// @notice Is excersizing options currently paused
    bool public isPaused;

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------
    /// @dev A modifier which checks that the caller has the admin role.
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert OptionToken_NoAdminRole();
        _;
    }

    /// @dev A modifier which checks that the caller has the admin role.
    modifier onlyMinter() {
        if (
            !hasRole(ADMIN_ROLE, msg.sender) &&
            !hasRole(MINTER_ROLE, msg.sender)
        ) revert OptionToken_NoMinterRole();
        _;
    }

    /// @dev A modifier which checks that the caller has the pause role.
    modifier onlyPauser() {
        if (!hasRole(PAUSER_ROLE, msg.sender))
            revert OptionToken_NoPauserRole();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        string memory _name,
        string memory _symbol,
        address _admin,
        ERC20 _paymentToken,
        ERC20 _underlyingToken,
        IUniswapV3Twap _twapOracle,
        IOptionFeeDistributor _feeDistributor,
        uint256 _discount,
        uint256 _veDiscount,
        address _votingEscrow
    ) ERC20(_name, _symbol) {
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);

        paymentToken = _paymentToken;
        underlyingToken = _underlyingToken;
        twapOracle = _twapOracle;
        feeDistributor = _feeDistributor;
        discount = _discount;
        veDiscount = _veDiscount;
        votingEscrow = _votingEscrow;

        paymentToken.approve(address(_feeDistributor), type(uint256).max);

        emit SetTwapOracleAndPaymentToken(_twapOracle, address(_paymentToken));
        emit SetFeeDistributor(_feeDistributor);
        emit SetDiscount(_discount);
        emit SetVeDiscount(_veDiscount);
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The oracle may revert if it cannot give a secure result.
    /// @param _amount The amount of options tokens to exercise
    /// @param _maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param _recipient The recipient of the purchased underlying tokens
    /// @return The amount paid to the fee distributor to purchase the underlying tokens
    function exercise(
        uint256 _amount,
        uint256 _maxPaymentAmount,
        address _recipient
    ) external returns (uint256) {
        return _exercise(_amount, _maxPaymentAmount, _recipient);
    }

    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The oracle may revert if it cannot give a secure result.
    /// @param _amount The amount of options tokens to exercise
    /// @param _maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param _recipient The recipient of the purchased underlying tokens
    /// @param _deadline The Unix timestamp (in seconds) after which the call will revert
    /// @return The amount paid to the fee distributor to purchase the underlying tokens
    function exercise(
        uint256 _amount,
        uint256 _maxPaymentAmount,
        address _recipient,
        uint256 _deadline
    ) external returns (uint256) {
        if (block.timestamp > _deadline) revert OptionToken_PastDeadline();
        return _exercise(_amount, _maxPaymentAmount, _recipient);
    }

    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The oracle may revert if it cannot give a secure result.
    /// @param _amount The amount of options tokens to exercise
    /// @param _maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param _recipient The recipient of the purchased underlying tokens
    /// @param _deadline The Unix timestamp (in seconds) after which the call will revert
    /// @return The amount paid to the fee distributor to purchase the underlying tokens
    function exerciseVe(
        uint256 _amount,
        uint256 _maxPaymentAmount,
        address _recipient,
        uint256 _deadline
    ) external returns (uint256, uint256) {
        if (block.timestamp > _deadline) revert OptionToken_PastDeadline();
        return _exerciseVe(_amount, _maxPaymentAmount, _recipient);
    }

    /// -----------------------------------------------------------------------
    /// Public functions
    /// -----------------------------------------------------------------------

    /// @notice Returns the discounted price in paymentTokens for a given amount of options tokens
    /// @param _amount The amount of options tokens to exercise
    /// @return The amount of payment tokens to pay to purchase the underlying tokens
    function getDiscountedPrice(uint256 _amount) public view returns (uint256) {
        return (getTimeWeightedAveragePrice(_amount) * discount) / 100;
    }

    /// @notice Returns the discounted price in paymentTokens for a given amount of options tokens redeemed to veFLOW
    /// @param _amount The amount of options tokens to exercise
    /// @return The amount of payment tokens to pay to purchase the underlying tokens
    function getVeDiscountedPrice(
        uint256 _amount
    ) public view returns (uint256) {
        return (getTimeWeightedAveragePrice(_amount) * veDiscount) / 100;
    }

    /// @notice Returns the average price in payment tokens over period defined in twapSeconds for a given amount of underlying tokens
    /// @param _amount The amount of underlying tokens to purchase
    /// @return The amount of payment tokens
    function getTimeWeightedAveragePrice(
        uint256 _amount
    ) public view returns (uint256) {
        return
            twapOracle.estimateAmountOut(
                address(underlyingToken),
                uint128(_amount),
                twapSeconds
            );
    }

    /// -----------------------------------------------------------------------
    /// Admin functions
    /// -----------------------------------------------------------------------


    function addGaugeFactory(address _gaugeFactory) public onlyAdmin {
        _grantRole(ADMIN_ROLE, _gaugeFactory);
    }

    /// @notice Sets the twap oracle contract address.
    /// @param _twapOracle The new twap oracle contract address
    function setTwapOracleAndPaymentToken(
        IUniswapV3Twap _twapOracle,
        address _paymentToken
    ) external onlyAdmin {
        if (
            !((_twapOracle.token0() == _paymentToken &&
                _twapOracle.token1() == address(underlyingToken)) ||
                (_twapOracle.token0() == address(underlyingToken) &&
                    _twapOracle.token1() == _paymentToken))
        ) revert OptionToken_IncorrectPairToken();
        twapOracle = _twapOracle;
        paymentToken = ERC20(_paymentToken);
        paymentToken.approve(address(feeDistributor), type(uint256).max);
        emit SetTwapOracleAndPaymentToken(_twapOracle, _paymentToken);
    }

    /// @notice Sets the fee distributor. Only callable by the admin.
    /// @param _feeDistributor The new fee distributor.
    function setFeeDistributor(
        IOptionFeeDistributor _feeDistributor
    ) external onlyAdmin {
        feeDistributor = _feeDistributor;
        paymentToken.approve(address(_feeDistributor), type(uint256).max);
        emit SetFeeDistributor(_feeDistributor);
    }

    /// @notice Sets the discount amount. Only callable by the admin.
    /// @param _discount The new discount amount.
    function setDiscount(uint256 _discount) external onlyAdmin {
        if (_discount > MAX_DISCOUNT || _discount == MIN_DISCOUNT)
            revert OptionToken_InvalidDiscount();
        discount = _discount;
        emit SetDiscount(_discount);
    }

    /// @notice Sets the further discount amount for locking. Only callable by the admin.
    /// @param _veDiscount The new discount amount.
    function setVeDiscount(uint256 _veDiscount) external onlyAdmin {
        if (_veDiscount > MAX_DISCOUNT || _veDiscount == MIN_DISCOUNT)
            revert OptionToken_InvalidDiscount();
        veDiscount = _veDiscount;
        emit SetVeDiscount(_veDiscount);
    }

    /// @notice Sets the twap seconds to control the length of our twap
    /// @param _twapSeconds The new twap points.
    function setTwapSeconds(uint32 _twapSeconds) external onlyAdmin {
        if (_twapSeconds > MAX_TWAP_SECONDS || _twapSeconds == 0)
            revert OptionToken_InvalidTwapSeconds();
        twapSeconds = _twapSeconds;
        emit SetTwapSeconds(_twapSeconds);
    }

    /// @notice Called by the admin to mint options tokens. Admin must grant token approval.
    /// @param _to The address that will receive the minted options tokens
    /// @param _amount The amount of options tokens that will be minted
    function mint(address _to, uint256 _amount) external onlyMinter {
        // transfer underlying tokens from the caller
        underlyingToken.transferFrom(msg.sender, address(this), _amount); // BLOTR reverts on failure
        // mint options tokens
        _mint(_to, _amount);
    }

    /// @notice Called by the admin to burn options tokens and transfer underlying tokens to the caller.
    /// @param _amount The amount of options tokens that will be burned and underlying tokens transferred to the caller
    function burn(uint256 _amount) external onlyAdmin {
        // transfer underlying tokens to the caller
        underlyingToken.transfer(msg.sender, _amount); // BLOTR reverts on failure
        // burn option tokens
        _burn(msg.sender, _amount);
    }

    /// @notice called by the admin to re-enable option exercising from a paused state.
    function unPause() external onlyAdmin {
        if (!isPaused) return;
        isPaused = false;
        emit PauseStateChanged(false);
    }

    /// -----------------------------------------------------------------------
    /// Pauser functions
    /// -----------------------------------------------------------------------
    function pause() external onlyPauser {
        if (isPaused) return;
        isPaused = true;
        emit PauseStateChanged(true);
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    function _exercise(
        uint256 _amount,
        uint256 _maxPaymentAmount,
        address _recipient
    ) internal returns (uint256 paymentAmount) {
        if (isPaused) revert OptionToken_Paused();

        // burn callers tokens
        _burn(msg.sender, _amount);
        paymentAmount = getDiscountedPrice(_amount);
        if (paymentAmount > _maxPaymentAmount)
            revert OptionToken_SlippageTooHigh();

        // transfer payment tokens from msg.sender to the fee distributor
        paymentToken.transferFrom(msg.sender, address(this), paymentAmount);
        feeDistributor.distribute(address(paymentToken), paymentAmount);

        // send underlying tokens to recipient
        underlyingToken.transfer(_recipient, _amount); // will revert on failure

        emit Exercise(msg.sender, _recipient, _amount, paymentAmount);
    }

    function _exerciseVe(
        uint256 _amount,
        uint256 _maxPaymentAmount,
        address _recipient
    ) internal returns (uint256 paymentAmount, uint256 nftId) {
        if (isPaused) revert OptionToken_Paused();

        // burn callers tokens
        _burn(msg.sender, _amount);
        paymentAmount = getVeDiscountedPrice(_amount);
        if (paymentAmount > _maxPaymentAmount)
            revert OptionToken_SlippageTooHigh();

        // transfer payment tokens from msg.sender to the fee distributor
        paymentToken.transferFrom(msg.sender, address(this), paymentAmount);
        feeDistributor.distribute(address(paymentToken), paymentAmount);

        // lock underlying tokens to veFLOW
        underlyingToken.approve(votingEscrow, _amount);
        nftId = IVotingEscrow(votingEscrow).create_lock_for(
            _amount,
            FULL_LOCK,
            _recipient
        );

        emit ExerciseVe(msg.sender, _recipient, _amount, paymentAmount, nftId);
    }
}
