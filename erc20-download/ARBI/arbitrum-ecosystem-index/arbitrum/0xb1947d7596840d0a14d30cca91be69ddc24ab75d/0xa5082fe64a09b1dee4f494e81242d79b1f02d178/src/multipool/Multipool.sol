// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only heart

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MpAsset, MpContext} from "./MpCommonMath.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/utils/ReentrancyGuardUpgradeable.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Multipool is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    function initialize(string memory mpName, string memory mpSymbol, address initialOwner) public initializer {
        __ERC20_init(mpName, mpSymbol);
        __ERC20Permit_init(mpName);
        __ReentrancyGuard_init();
        __Ownable_init(initialOwner);
        priceAuthority = initialOwner;
        targetShareAuthority = initialOwner;
        withdrawAuthority = initialOwner;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    event AssetTargetShareChange(address indexed asset, uint share);
    event AssetQuantityChange(address indexed asset, uint quantity);
    event AssetPriceChange(address indexed asset, uint price);
    event WithdrawFees(address indexed asset, uint value);

    event TargetShareAuthorityChange(address authority);
    event PriceAuthorityChange(address authority);
    event WithdrawAuthorityChange(address authority);

    event HalfDeviationFeeChange(uint value);
    event DeviationLimitChange(uint value);
    event BaseMintFeeChange(uint value);
    event BaseBurnFeeChange(uint value);
    event BaseTradeFeeChange(uint value);
    event DepegBaseFeeChange(uint value);

    /**
     * ---------------- Variables ------------------
     */

    mapping(address => MpAsset) public assets;
    uint public usdCap;
    uint public totalTargetShares;

    uint public halfDeviationFee;
    uint public deviationLimit;
    uint public depegBaseFee;

    uint public baseMintFee;
    uint public baseBurnFee;
    uint public baseTradeFee;
    uint public constant DENOMINATOR = 1e18;

    address public priceAuthority;
    address public targetShareAuthority;
    address public withdrawAuthority;

    bool public isPaused;
    bool public audited;

    modifier notPaused() {
        require(!isPaused, "MULTIPOOL: IP");
        _;
    }

    /**
     * ---------------- Methods ------------------
     */

    function getAsset(address assetAddress) public view returns (MpAsset memory asset) {
        asset = assets[assetAddress];
    }

    function getMintData(address assetAddress)
        public
        view
        returns (MpContext memory context, MpAsset memory asset, uint ts)
    {
        context = getContext(0);
        asset = assets[assetAddress];
        ts = totalSupply();
    }

    function getBurnData(address assetAddress)
        public
        view
        returns (MpContext memory context, MpAsset memory asset, uint ts)
    {
        context = getContext(1);
        asset = assets[assetAddress];
        ts = totalSupply();
    }

    function getTradeData(address assetInAddress, address assetOutAddress)
        public
        view
        returns (MpContext memory context, MpAsset memory assetIn, MpAsset memory assetOut, uint ts)
    {
        context = getContext(2);
        assetIn = assets[assetInAddress];
        assetOut = assets[assetOutAddress];
        ts = totalSupply();
    }

    // 0 - mint
    // 1 - burn
    // 2 - swap
    function getContext(uint action) public view returns (MpContext memory context) {
        context = MpContext({
            usdCap: usdCap,
            totalTargetShares: totalTargetShares,
            halfDeviationFee: halfDeviationFee,
            deviationLimit: deviationLimit,
            operationBaseFee: action == 0 ? baseMintFee : (action == 1 ? baseBurnFee : baseTradeFee),
            userCashbackBalance: 0e18,
            depegBaseFee: depegBaseFee
        });
    }

    function getTransferredAmount(MpAsset memory asset, address assetAddress) public view returns (uint amount) {
        amount = asset.to18(IERC20(assetAddress).balanceOf(address(this))) - asset.quantity - asset.collectedFees
            - asset.collectedCashbacks;
    }

    function shareToAmount(uint share, MpContext memory context, MpAsset memory asset, uint mpTotalSupply)
        internal
        pure
        returns (uint amount)
    {
        amount = (share * context.usdCap * DENOMINATOR) / mpTotalSupply / asset.price;
    }

    function massiveMint(address[] calldata assetAddresses, address to)
        public
        notPaused
        nonReentrant
        returns (uint share)
    {
        MpAsset[] memory mintAssets = new MpAsset[](assetAddresses.length);
        uint totalUsd;
        uint minShare;

        for (uint i = 0; i < assetAddresses.length; i++) {
            mintAssets[i] = assets[assetAddresses[i]];
            totalUsd += mintAssets[i].price * mintAssets[i].quantity / DENOMINATOR;
            require(mintAssets[i].quantity != 0, "MULTIPOOL: IL");
            uint transferredAmount = getTransferredAmount(mintAssets[i], assetAddresses[i]);
            uint maxShareToMint = totalSupply() * transferredAmount / mintAssets[i].quantity;
            require(maxShareToMint != 0, "MULTIPOOL: IQ");
            if (minShare == 0 || maxShareToMint < minShare) {
                minShare = maxShareToMint;
            }
        }

        require(totalUsd == usdCap, "MULTIPOOL: IL");
        uint mintFee = baseMintFee;
        uint newUsdCap = usdCap;

        for (uint i = 0; i < assetAddresses.length; i++) {
            uint quantity = mintAssets[i].quantity * minShare / totalSupply();
            require(quantity != 0, "MULTIPOOL: ZQ");
            uint fees = quantity * mintFee / DENOMINATOR;
            quantity = quantity - fees;
            newUsdCap -= mintAssets[i].quantity * mintAssets[i].price / DENOMINATOR;
            mintAssets[i].quantity += quantity;
            mintAssets[i].collectedFees += fees;
            newUsdCap += mintAssets[i].quantity * mintAssets[i].price / DENOMINATOR;
            emit AssetQuantityChange(assetAddresses[i], mintAssets[i].quantity);
            assets[assetAddresses[i]] = mintAssets[i];
        }
        usdCap = newUsdCap;
        minShare = minShare - minShare * mintFee / DENOMINATOR;
        require(minShare != 0, "MULTIPOOL: ZS");
        _mint(to, minShare);
        return minShare;
    }

    function mint(address assetAddress, uint share, address to)
        public
        notPaused
        nonReentrant
        returns (uint amountIn, uint refund)
    {
        require(share != 0, "MULTIPOOL: ZS");
        MpAsset memory asset = assets[assetAddress];
        require(asset.price != 0, "MULTIPOOL: ZP");
        require(asset.share != 0, "MULTIPOOL: ZT");
        MpContext memory context = getContext(0);

        uint transferredAmount = getTransferredAmount(asset, assetAddress);
        uint amountOut = totalSupply() != 0 ? shareToAmount(share, context, asset, totalSupply()) : transferredAmount;

        amountIn = context.evalMint(asset, amountOut);
        require(amountIn != 0, "MULTIPOOL: ZQ");
        require(amountIn <= transferredAmount, "MULTIPOOL: IQ");

        usdCap = context.usdCap;
        // add unused quantity to refund
        refund = context.userCashbackBalance;
        uint returnAmount = (transferredAmount - amountIn) + refund;

        _mint(to, share);
        assets[assetAddress] = asset;
        emit AssetQuantityChange(assetAddress, asset.quantity);
        if (returnAmount > 0) {
            require(IERC20(assetAddress).transfer(to, asset.toNative(returnAmount)), "MULTIPOOL: TF");
        }
    }

    // share here needs to be specified and can't be taken by balance of because
    // if there is too much share you will be frozen by deviaiton limit overflow
    function burn(address assetAddress, uint share, address to)
        public
        notPaused
        nonReentrant
        returns (uint amountOut, uint refund)
    {
        require(share != 0, "MULTIPOOL: ZS");
        MpAsset memory asset = assets[assetAddress];
        require(asset.price != 0, "MULTIPOOL: ZP");
        MpContext memory context = getContext(1);

        uint amountIn = shareToAmount(share, context, asset, totalSupply());
        amountOut = context.evalBurn(asset, amountIn);
        require(amountOut != 0, "MULTIPOOL: ZQ");

        usdCap = context.usdCap;
        refund = context.userCashbackBalance;

        _burn(address(this), share);
        assets[assetAddress] = asset;
        _transfer(address(this), to, balanceOf(address(this)));
        emit AssetQuantityChange(assetAddress, asset.quantity);
        require(IERC20(assetAddress).transfer(to, asset.toNative(amountOut + refund)), "MULTIPOOL: TF");
    }

    function swap(address assetInAddress, address assetOutAddress, uint share, address to)
        public
        notPaused
        nonReentrant
        returns (uint amountIn, uint amountOut, uint refundIn, uint refundOut)
    {
        require(assetInAddress != assetOutAddress, "MULTIPOOL: SA");
        require(share != 0, "MULTIPOOL: ZS");
        MpAsset memory assetIn = assets[assetInAddress];
        MpAsset memory assetOut = assets[assetOutAddress];
        require(assetIn.price != 0, "MULTIPOOL: ZP");
        require(assetIn.share != 0, "MULTIPOOL: ZT");
        require(assetOut.price != 0, "MULTIPOOL: ZP");
        MpContext memory context = getContext(2);

        uint transferredAmount = getTransferredAmount(assetIn, assetInAddress);
        {
            {
                uint _amountOut = shareToAmount(share, context, assetIn, totalSupply());
                amountIn = context.evalMint(assetIn, _amountOut);
                require(amountIn != 0, "MULTIPOOL: ZQ");
                require(amountIn <= transferredAmount, "MULTIPOOL: IQ");

                refundIn = context.userCashbackBalance;
                context.userCashbackBalance = 0;
            }
        }

        {
            {
                uint _amountIn = shareToAmount(share, context, assetOut, totalSupply() + share);
                amountOut = context.evalBurn(assetOut, _amountIn);

                refundOut = context.userCashbackBalance;
                usdCap = context.usdCap;
            }
        }

        assets[assetInAddress] = assetIn;
        assets[assetOutAddress] = assetOut;

        emit AssetQuantityChange(assetInAddress, assetIn.quantity);
        emit AssetQuantityChange(assetOutAddress, assetOut.quantity);
        if (amountOut + refundOut > 0) {
            require(IERC20(assetOutAddress).transfer(to, assetOut.toNative(amountOut + refundOut)), "MULTIPOOL: TF");
        }
        if (refundIn + (transferredAmount - amountIn) > 0) {
            require(
                IERC20(assetInAddress).transfer(to, assetIn.toNative(refundIn + (transferredAmount - amountIn))),
                "MULTIPOOL: TF"
            );
        }
    }

    function increaseCashback(address assetAddress) public notPaused nonReentrant returns (uint amount) {
        MpAsset storage asset = assets[assetAddress];
        amount = getTransferredAmount(asset, assetAddress);
        asset.collectedCashbacks += amount;
    }

    /**
     * ---------------- Authorities ------------------
     */

    function updatePrices(address[] calldata assetAddresses, uint[] calldata prices) public notPaused {
        require(priceAuthority == msg.sender, "MULTIPOOL: PA");
        for (uint a = 0; a < assetAddresses.length; a++) {
            MpAsset storage asset = assets[assetAddresses[a]];
            usdCap = usdCap - (asset.quantity * asset.price) / DENOMINATOR + (asset.quantity * prices[a]) / DENOMINATOR;
            asset.price = prices[a];
            emit AssetPriceChange(assetAddresses[a], prices[a]);
        }
    }

    function updateTargetShares(address[] calldata assetAddresses, uint[] calldata shares) public notPaused {
        require(targetShareAuthority == msg.sender, "MULTIPOOL: TA");
        for (uint a = 0; a < assetAddresses.length; a++) {
            MpAsset storage asset = assets[assetAddresses[a]];
            totalTargetShares = totalTargetShares - asset.share + shares[a];
            asset.share = shares[a];
            emit AssetTargetShareChange(assetAddresses[a], shares[a]);
        }
    }

    function withdrawFees(address assetAddress, address to) public notPaused returns (uint fees) {
        require(withdrawAuthority == msg.sender, "MULTIPOOL: WA");
        MpAsset storage asset = assets[assetAddress];
        fees = asset.collectedFees;
        asset.collectedFees = 0;
        emit WithdrawFees(assetAddress, fees);
        require(IERC20(assetAddress).transfer(to, asset.toNative(fees)), "MULTIPOOL: TF");
    }

    /**
     * ---------------- Owner ------------------
     */

    function togglePause() external onlyOwner {
        isPaused = !isPaused;
    }

    function setAudited() external onlyOwner {
        audited = true;
    }

    function emergencyWithdraw(address assetAddress, address to) public onlyOwner {
        require(!audited, "MULTIPOOL: IA");
        uint balance = IERC20(assetAddress).balanceOf(address(this));
        require(IERC20(assetAddress).transfer(to, balance));
    }

    function setTokenDecimals(address assetAddress, uint decimals) external onlyOwner {
        MpAsset storage asset = assets[assetAddress];
        asset.decimals = decimals;
    }

    function setDeviationLimit(uint newDeviationLimit) external onlyOwner {
        deviationLimit = newDeviationLimit;
        emit DeviationLimitChange(newDeviationLimit);
    }

    function setHalfDeviationFee(uint newHalfDeviationFee) external onlyOwner {
        halfDeviationFee = newHalfDeviationFee;
        emit HalfDeviationFeeChange(newHalfDeviationFee);
    }

    function setBaseTradeFee(uint newBaseTradeFee) external onlyOwner {
        baseTradeFee = newBaseTradeFee;
        emit BaseTradeFeeChange(newBaseTradeFee);
    }

    function setBaseMintFee(uint newBaseMintFee) external onlyOwner {
        baseMintFee = newBaseMintFee;
        emit BaseMintFeeChange(newBaseMintFee);
    }

    function setDepegBaseFee(uint newDepegBaseFee) external onlyOwner {
        depegBaseFee = newDepegBaseFee;
        emit DepegBaseFeeChange(newDepegBaseFee);
    }

    function setBaseBurnFee(uint newBaseBurnFee) external onlyOwner {
        baseBurnFee = newBaseBurnFee;
        emit BaseBurnFeeChange(newBaseBurnFee);
    }

    function setPriceAuthority(address newPriceAuthority) external onlyOwner {
        require(newPriceAuthority != address(0), "MULTIPOOL: IA");
        priceAuthority = newPriceAuthority;
        emit PriceAuthorityChange(newPriceAuthority);
    }

    function setTargetShareAuthority(address newTargetShareAuthority) external onlyOwner {
        require(newTargetShareAuthority != address(0), "MULTIPOOL: IA");
        targetShareAuthority = newTargetShareAuthority;
        emit TargetShareAuthorityChange(newTargetShareAuthority);
    }

    function setWithdrawAuthority(address newWithdrawAuthority) external onlyOwner {
        require(newWithdrawAuthority != address(0), "MULTIPOOL: IA");
        withdrawAuthority = newWithdrawAuthority;
        emit WithdrawAuthorityChange(newWithdrawAuthority);
    }
}
