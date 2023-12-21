// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IVolatilityToken.sol";
import "./interfaces/IVolatilityTokenManagement.sol";
import "./ElasticToken.sol";
import "./interfaces/IOldPlatformMinimal.sol";
import './external/ISwapRouter.sol';

contract VolatilityToken is Initializable, IVolatilityToken, IVolatilityTokenManagement, ReentrancyGuardUpgradeable, ElasticToken {

    // Obsolete
    struct Request {
        uint8 requestType; // 1 => mint, 2 => burn
        uint168 tokenAmount;
        uint16 timeDelayRequestFeesPercent;
        uint16 maxRequestFeesPercent;
        address owner;
        uint32 requestTimestamp;
        uint32 targetTimestamp;
        bool useKeepers;
        uint16 maxBuyingPremiumFeePercentage;
    }

    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint16 public constant MAX_PERCENTAGE = 10000;
    uint32 public constant MAX_FEE_PERCENTAGE = 1000000;

    uint8 public override leverage; // Obsolete
    uint8 private rebaseLag; // Obsolete

    uint16 public minDeviationPercentage;

    uint256 public override initialTokenToLPTokenRate;

    IERC20Upgradeable public token;
    IPlatform public override platform;
    IFeesCollector public feesCollector;
    IFeesCalculator public feesCalculator;
    address public requestFeesCalculator; // Obsolete
    ICVIOracle public cviOracle;

    uint256 public nextRequestId; // Obsolete

    mapping(uint256 => Request) public requests; // Obsolete

    uint256 public totalRequestsAmount; // Obsolete
    uint256 public maxTotalRequestsAmount; // Obsolete
    bool public verifyTotalRequestsAmount; // Obsolete

    uint16 public deviationPerSingleRebaseLag;
    uint16 public maxDeviationPercentage;

    bool public cappedRebase;

    uint256 public constant PRECISION_DECIMALS = 1e10;
    uint256 public constant CVI_DECIMALS_FIX = 100;

    uint256 public minRequestId; // Obsolete
    uint256 public maxMinRequestIncrements; // Obsolete

    address public fulfiller;

    address public keepersFeeVaultAddress; // Obsolete

    uint256 public minKeepersMintAmount; // Obsolete
    uint256 public minKeepersBurnAmount; // Obsolete

    IThetaVault public thetaVault;
    address public positionManagerAddress;
    
    address public minter;

    uint256 public postLiquidationMaxMintAmount;

    constructor() {
        _disableInitializers();
    }

    function initialize(IERC20Upgradeable _token, string memory _lpTokenName, string memory _lpTokenSymbolName, uint256 _initialTokenToVolTokenRate, 
            IPlatform _platform, IFeesCollector _feesCollector, IFeesCalculator _feesCalculator, ICVIOracle _cviOracle) public initializer {
        minDeviationPercentage = 100;
        deviationPerSingleRebaseLag = 1000;
        maxDeviationPercentage = 5000;
        cappedRebase = true;
        postLiquidationMaxMintAmount = 10e6;

        ElasticToken.__ElasticToken_init(_lpTokenName, _lpTokenSymbolName, 18);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        token = _token;
        platform = _platform;
        feesCollector = _feesCollector;
        feesCalculator = _feesCalculator;
        cviOracle = _cviOracle;
        initialTokenToLPTokenRate = _initialTokenToVolTokenRate;

        if (address(token) != address(0)) {
            token.safeApprove(address(_platform), type(uint256).max);
            token.safeApprove(address(_feesCollector), type(uint256).max);
        }
    }

    // If not rebaser, the rebase underlying method will revert
    function rebaseCVI() external override {
        (uint256 balance, bool isBalancePositive,,,,) = platform.calculatePositionBalance(address(this));
        require(isBalancePositive, "Negative balance");

        // Note: the price is measured by token units, so we want its decimals on the position value as well, as precision decimals
        // We use the rate multiplication to have balance / totalSupply be done with matching decimals
        uint256 positionValue = balance * initialTokenToLPTokenRate * PRECISION_DECIMALS / totalSupply;

        (uint256 cviValueOracle,,) = cviOracle.getCVILatestRoundData();
        uint256 cviValue = cviValueOracle * PRECISION_DECIMALS / CVI_DECIMALS_FIX;

        require(cviValue > positionValue, "Positive rebase disallowed");
        uint256 deviation = cviValue - positionValue;

        require(!cappedRebase || deviation >= cviValue * minDeviationPercentage / MAX_PERCENTAGE, "Not enough deviation");
        require(!cappedRebase || deviation <= cviValue * maxDeviationPercentage / MAX_PERCENTAGE, "Deviation too big");

        // Note: rounding up (ceiling) the rebase lag so it is >= 1 and bumps by 1 for every deviationPerSingleRebaseLag percentage
        uint256 rebaseLagNew = cappedRebase ? (deviation * MAX_PERCENTAGE - 1) / (cviValue * deviationPerSingleRebaseLag) + 1 : 1;

        if (rebaseLagNew > 1) {
            deviation = deviation / rebaseLagNew;
            cviValue = positionValue + deviation;
        }

        uint256 delta = DELTA_PRECISION_DECIMALS * deviation / cviValue;

        rebase(delta, false);
    }

    function mintTokensForOwner(address _owner, uint168 _tokenAmount, uint32 _maxBuyingPremiumFeePercentage, uint32 _realTimeCVIValue) external override returns (uint256 tokensMinted) {
        require(msg.sender == fulfiller); // Not allowed
        (uint32 cviValue,,) = cviOracle.getCVILatestRoundData();
        uint32 closeCVIValue = cviValue;
        
        if (cviValue < _realTimeCVIValue) {
            cviValue = _realTimeCVIValue;
        }

        if (closeCVIValue > _realTimeCVIValue) {
            closeCVIValue = _realTimeCVIValue;
        }

        // When minting tokens, the minimum cvi is used to close the position in case of merge (nearly always in vol token),
        // and maximum to open the position, so that the user will always have the less-profittable value, preventing front runs
        tokensMinted = mintTokens(_owner, _tokenAmount, _maxBuyingPremiumFeePercentage, true, closeCVIValue, cviValue);
    }

    function burnTokensForOwner(address _owner, uint168 _burnAmount, uint32 _realTimeCVIValue) external override returns (uint256 tokensReceived) {
        require(msg.sender == fulfiller); // Not allowed

        (uint32 cviValue,,) = cviOracle.getCVILatestRoundData();
        if (cviValue > _realTimeCVIValue) {
            cviValue = _realTimeCVIValue;
        }

        // When burning tokens, the maximum cvi is used to close the position,
        // so that the user will always have the less-profittable value, preventing front runs
        tokensReceived = burnTokens(_owner, _burnAmount, true, cviValue);
    }

    function mintTokens(uint168 _tokenAmount, uint32 _closeCVIValue, uint32 _cviValue) external override returns (uint256 tokensMinted) {
        require(msg.sender == minter);
        tokensMinted = mintTokens(msg.sender, _tokenAmount, MAX_FEE_PERCENTAGE, false, _closeCVIValue, _cviValue);
    }

    function burnTokens(uint168 _burnAmount, uint32 _cviValue) external override returns (uint256 tokensReceived) {
        require(msg.sender == minter);
        tokensReceived = burnTokens(msg.sender, _burnAmount, false, _cviValue);
    }

    function setMinter(address _newMinter) external override onlyOwner {
        minter = _newMinter;

        emit MinterSet(_newMinter);
    }

    function setPlatform(IPlatform _newPlatform, IERC20Upgradeable _newToken, ISwapRouter _swapRouter) external override onlyOwner {
        require(address(_newPlatform) != address(0) && address(_newPlatform) != address(platform), "Same Platform");
        uint256 tokenAmount = 0;

        (uint32 cviValue,,) = cviOracle.getCVILatestRoundData();

        if (address(platform) != address(0) && address(token) != address(0)) {
            (, bool isPositive, uint168 totalPositionUnits,,,) = platform.calculatePositionBalance(address(this));
            require(isPositive, "Negative balance");
            
            (tokenAmount,,) = IOldPlatformMinimal(address(platform)).closePosition(totalPositionUnits, 1);
            token.safeApprove(address(platform), 0);
        }

        token.safeApprove(address(feesCollector), 0);
        if(address(_swapRouter) != address(0)) {
            token.safeApprove(address(_swapRouter), tokenAmount);
            uint256 minAmount = tokenAmount * 999 / 1000;
            tokenAmount = _swapRouter.exactInput(ISwapRouter.ExactInputParams(abi.encodePacked(token, uint24(100), _newToken), address(this), block.timestamp, tokenAmount, minAmount));
        } 

        token = _newToken;
        token.safeApprove(address(feesCollector), type(uint256).max);

        platform = _newPlatform;

        if (address(_newPlatform) != address(0) && address(token) != address(0)) {
            token.safeApprove(address(_newPlatform), type(uint256).max);

            if (tokenAmount > 0) {
                require(uint168(tokenAmount) == tokenAmount, "Overflow");
                platform.openPosition(uint168(tokenAmount), platform.maxCVIValue(), MAX_FEE_PERCENTAGE, 1, false, cviValue, cviValue);
            }
        }

        emit PlatformSet(address(_newPlatform), address(_newToken), address(_swapRouter));
    }

    function setFeesCalculator(IFeesCalculator _newFeesCalculator) external override onlyOwner {
        feesCalculator = _newFeesCalculator;

        emit FeesCalculatorSet(address(_newFeesCalculator));
    }

    function setFeesCollector(IFeesCollector _newCollector) external override onlyOwner {
        if (address(feesCollector) != address(0) && address(token) != address(0)) {
            token.safeApprove(address(feesCollector), 0);
        }

        feesCollector = _newCollector;

        if (address(_newCollector) != address(0) && address(token) != address(0)) {
            token.safeApprove(address(_newCollector), type(uint256).max);
        }

        emit FeesCollectorSet(address(_newCollector));
    }

    function setCVIOracle(ICVIOracle _newCVIOracle) external override onlyOwner {
        cviOracle = _newCVIOracle;

        emit CVIOracleSet(address(_newCVIOracle));
    }

    function setDeviationParameters(uint16 _newDeviationPercentagePerSingleRebaseLag, uint16 _newMinDeviationPercentage, uint16 _newMaxDeviationPercentage) external override onlyOwner {
        deviationPerSingleRebaseLag = _newDeviationPercentagePerSingleRebaseLag;
        minDeviationPercentage = _newMinDeviationPercentage;
        maxDeviationPercentage = _newMaxDeviationPercentage;

        emit DeviationParametersSet(_newDeviationPercentagePerSingleRebaseLag, _newMinDeviationPercentage, _newMaxDeviationPercentage);
    }

    function setCappedRebase(bool _newCappedRebase) external override onlyOwner {
        cappedRebase = _newCappedRebase;

        emit CappedRebaseSet(_newCappedRebase);
    }

    function setThetaVault(IThetaVault _newThetaVault) external override onlyOwner {
        thetaVault = _newThetaVault;

        emit ThetaVaultSet(address(_newThetaVault));
    }

    function setPositionManager(address _newPositionManagerAddress) external override onlyOwner {
        positionManagerAddress = _newPositionManagerAddress;

        emit PositionManagerSet(_newPositionManagerAddress);
    }

    function setFulfiller(address _mewFulfiller) external override onlyOwner {
        fulfiller = _mewFulfiller;

        emit FulfillerSet(_mewFulfiller);
    }

    function setPostLiquidationMaxMintAmount(uint256 _newPostLiquidationMaxMintAmount) external override onlyOwner {
        postLiquidationMaxMintAmount = _newPostLiquidationMaxMintAmount;

        emit PostLiquidationMaxMintAmountSet(_newPostLiquidationMaxMintAmount);
    }

    function _beforeTokenTransfer(address from, address to, uint256) internal view override {
        if (address(thetaVault) != address(0) && positionManagerAddress != address(0) &&
                to == positionManagerAddress && from != address(thetaVault)) {
            revert("Not allowed");
        }
    }

    function mintTokens(address _owner, uint168 _tokenAmount, uint32 _maxBuyingPremiumFeePercentage, bool _chargeOpenFee, uint32 _closeCVIValue, uint32 _cviValue) private returns (uint256 tokensMinted) {
        uint256 balance = 0;
        uint256 supply = totalSupply;
        bool wasLiquidated = false;

        {
            bool isPositive = true;

            (uint256 currPositionUnits,,,,,) = platform.positions(address(this));
            if (currPositionUnits != 0) {
                (balance, isPositive,,,,) = platform.calculatePositionBalance(address(this));
            } else if (supply > 0) {
                // This means vol token was liquidated, since supply is positive but there is no position anymore
                wasLiquidated = true;
            }
            require(isPositive, "Negative balance");
        }

        token.safeTransferFrom(_owner, address(this), _tokenAmount);
        (uint256 positionedTokenAmount, uint256 openPositionFee, uint256 buyingPremiumFee) = openPosition(_tokenAmount, _maxBuyingPremiumFeePercentage, _chargeOpenFee, _closeCVIValue, _cviValue);

        if (supply > 0 && balance > 0) {
            tokensMinted = positionedTokenAmount * supply / balance;
        } else {
            if (address(thetaVault) != address(0) && !wasLiquidated) {
                tokensMinted = positionedTokenAmount * (10 ** ERC20Upgradeable(address(this)).decimals()) / 
                    thetaVault.liquidityManager().getDexPrice();
            } else {
                require(_tokenAmount <= postLiquidationMaxMintAmount, "Mint too big");
                tokensMinted = positionedTokenAmount * initialTokenToLPTokenRate;
            }
        }

        // Request id is obsolete, so using zero
        emit Mint(0, _owner, _tokenAmount, positionedTokenAmount, tokensMinted, openPositionFee, buyingPremiumFee);

        require(tokensMinted > 0, "Too few tokens");

        _mint(_owner, tokensMinted);
    }

    function burnTokens(address _owner, uint168 _tokenAmount, bool _chargeCloseFee, uint32 _cviValue) private returns (uint256 tokensReceived) {
        require(balanceOf(_owner) >= _tokenAmount, "Not enough tokens");
        IERC20Upgradeable(address(this)).safeTransferFrom(_owner, address(this), underlyingToValue(valueToUnderlying(uint256(_tokenAmount))));

        uint256 closePositionFee;
        uint256 closingPremiumFee;

        (tokensReceived, closePositionFee, closingPremiumFee) = _burnTokens(_tokenAmount, _chargeCloseFee, _cviValue);
        token.safeTransfer(_owner, tokensReceived);

        // Request id is obsolete, so using zero
        emit Burn(0, _owner, tokensReceived, tokensReceived, _tokenAmount, closePositionFee, closingPremiumFee);
    }

    function _burnTokens(uint256 _tokenAmount, bool _chargeCloseFee, uint32 _cviValue) private returns (uint256 tokensReceived, uint256 closePositionFee, uint256 closingPremiumFee) {
        (, bool isPositive, uint168 totalPositionUnits,,,) = platform.calculatePositionBalance(address(this));
        require(isPositive, "Negative balance");

        uint256 positionUnits = totalPositionUnits * _tokenAmount / totalSupply;
        require(positionUnits == uint168(positionUnits), "Too much position units");

        if (positionUnits > 0) {
            (tokensReceived, closePositionFee, closingPremiumFee) = platform.closePosition(uint168(positionUnits), 1, _chargeCloseFee, _cviValue);
        }

        // Note: Moving to underlying and back in case rebase occured, and trying to burn too much because of rounding
        _burn(address(this), underlyingToValue(valueToUnderlying(_tokenAmount)));
    }

    function openPosition(uint168 _amount, uint32 _maxBuyingPremiumFeePercentage, bool _chargeOpenFee, uint32 _closeCVIValue, uint32 _cviValue) private returns (uint168 positionedTokenAmount, uint168 openPositionFee, uint168 buyingPremiumFee) {
        (, positionedTokenAmount, openPositionFee, buyingPremiumFee) = 
            platform.openPosition(_amount, platform.maxCVIValue(), _maxBuyingPremiumFeePercentage, 1, _chargeOpenFee, _closeCVIValue, _cviValue);
    }
}
