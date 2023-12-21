// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./openzeppelin/security/ReentrancyGuard.sol";
import "./openzeppelin/token/ERC20/ERC20.sol";
import "./openzeppelin/interfaces/IERC165.sol";

import "../interfaces/ITitanOnBurn.sol";
import "../interfaces/ITITANX.sol";

import "../libs/calcFunctions.sol";

import "./GlobalInfo.sol";
import "./MintInfo.sol";
import "./StakeInfo.sol";
import "./BurnInfo.sol";
import "./OwnerInfo.sol";

//custom errors
error TitanX_InvalidAmount();
error TitanX_InsufficientBalance();
error TitanX_NotSupportedContract();
error TitanX_InsufficientProtocolFees();
error TitanX_FailedToSendAmount();
error TitanX_NotAllowed();
error TitanX_NoCycleRewardToClaim();
error TitanX_NoSharesExist();
error TitanX_EmptyUndistributeFees();
error TitanX_InvalidBurnRewardPercent();
error TitanX_InvalidBatchCount();
error TitanX_InvalidMintLadderInterval();
error TitanX_InvalidMintLadderRange();
error TitanX_MaxedWalletMints();
error TitanX_LPTokensHasMinted();
error TitanX_InvalidAddress();
error TitanX_InsufficientBurnAllowance();

/** @title Titan X */
contract TITANX is ERC20, ReentrancyGuard, GlobalInfo, MintInfo, StakeInfo, BurnInfo, OwnerInfo {
    /** Storage Variables*/
    /** @dev stores genesis wallet address */
    address private s_genesisAddress;
    /** @dev stores buy and burn contract address */
    address private s_buyAndBurnAddress;

    /** @dev tracks collected protocol fees until it is distributed */
    uint88 private s_undistributedEth;
    /** @dev tracks burn reward from distributeETH() until payout is triggered */
    uint88 private s_cycleBurnReward;

    /** @dev tracks if initial LP tokens has minted or not */
    InitialLPMinted private s_initialLPMinted;

    /** @dev trigger to turn on burn pool reward */
    BurnPoolEnabled private s_burnPoolEnabled;

    /** @dev tracks user + project burn mints allowance */
    mapping(address => mapping(address => uint256)) private s_allowanceBurnMints;

    /** @dev tracks user + project burn stakes allowance */
    mapping(address => mapping(address => uint256)) private s_allowanceBurnStakes;

    event ProtocolFeeRecevied(address indexed user, uint256 indexed day, uint256 indexed amount);
    event ETHDistributed(address indexed caller, uint256 indexed amount);
    event CyclePayoutTriggered(
        address indexed caller,
        uint256 indexed cycleNo,
        uint256 indexed reward,
        uint256 burnReward
    );
    event RewardClaimed(address indexed user, uint256 indexed reward);
    event ApproveBurnStakes(address indexed user, address indexed project, uint256 indexed amount);
    event ApproveBurnMints(address indexed user, address indexed project, uint256 indexed amount);

    constructor(address genesisAddress, address buyAndBurnAddress) ERC20("TITAN X", "TITANX") {
        if (genesisAddress == address(0)) revert TitanX_InvalidAddress();
        if (buyAndBurnAddress == address(0)) revert TitanX_InvalidAddress();
        s_genesisAddress = genesisAddress;
        s_buyAndBurnAddress = buyAndBurnAddress;
    }

    /**** Mint Functions *****/
    /** @notice create a new mint
     * @param mintPower 1 - 100
     * @param numOfDays mint length of 1 - 280
     */
    function startMint(
        uint256 mintPower,
        uint256 numOfDays
    ) external payable nonReentrant dailyUpdate {
        if (getUserLatestMintId(_msgSender()) + 1 > MAX_MINT_PER_WALLET)
            revert TitanX_MaxedWalletMints();
        uint256 gMintPower = getGlobalMintPower() + mintPower;
        uint256 currentTRank = getGlobalTRank() + 1;
        uint256 gMinting = getTotalMinting() +
            _startMint(
                _msgSender(),
                mintPower,
                numOfDays,
                getCurrentMintableTitan(),
                getCurrentMintPowerBonus(),
                getCurrentEAABonus(),
                getUserBurnAmplifierBonus(_msgSender()),
                gMintPower,
                currentTRank,
                getBatchMintCost(mintPower, 1, getCurrentMintCost())
            );
        _updateMintStats(currentTRank, gMintPower, gMinting);
        _protocolFees(mintPower, 1);
    }

    /** @notice create new mints in batch of up to 100 mints
     * @param mintPower 1 - 100
     * @param numOfDays mint length of 1 - 280
     * @param count 1 - 100
     */
    function batchMint(
        uint256 mintPower,
        uint256 numOfDays,
        uint256 count
    ) external payable nonReentrant dailyUpdate {
        if (count == 0 || count > MAX_BATCH_MINT_COUNT) revert TitanX_InvalidBatchCount();
        if (getUserLatestMintId(_msgSender()) + count > MAX_MINT_PER_WALLET)
            revert TitanX_MaxedWalletMints();

        _startBatchMint(
            _msgSender(),
            mintPower,
            numOfDays,
            getCurrentMintableTitan(),
            getCurrentMintPowerBonus(),
            getCurrentEAABonus(),
            getUserBurnAmplifierBonus(_msgSender()),
            count,
            getBatchMintCost(mintPower, 1, getCurrentMintCost()) //only need 1 mint cost for all mints
        );
        _protocolFees(mintPower, count);
    }

    /** @notice create new mints in ladder up to 100 mints
     * @param mintPower 1 - 100
     * @param minDay minimum mint length
     * @param maxDay maximum mint lenght
     * @param dayInterval day increase from previous mint length
     * @param countPerInterval how many mints per mint length
     */
    function batchMintLadder(
        uint256 mintPower,
        uint256 minDay,
        uint256 maxDay,
        uint256 dayInterval,
        uint256 countPerInterval
    ) external payable nonReentrant dailyUpdate {
        if (dayInterval == 0) revert TitanX_InvalidMintLadderInterval();
        if (maxDay < minDay || minDay == 0 || maxDay > MAX_MINT_LENGTH)
            revert TitanX_InvalidMintLadderRange();

        uint256 count = getBatchMintLadderCount(minDay, maxDay, dayInterval, countPerInterval);
        if (count == 0 || count > MAX_BATCH_MINT_COUNT) revert TitanX_InvalidBatchCount();
        if (getUserLatestMintId(_msgSender()) + count > MAX_MINT_PER_WALLET)
            revert TitanX_MaxedWalletMints();

        uint256 mintCost = getBatchMintCost(mintPower, 1, getCurrentMintCost()); //only need 1 mint cost for all mints

        _startbatchMintLadder(
            _msgSender(),
            mintPower,
            minDay,
            maxDay,
            dayInterval,
            countPerInterval,
            getCurrentMintableTitan(),
            getCurrentMintPowerBonus(),
            getCurrentEAABonus(),
            getUserBurnAmplifierBonus(_msgSender()),
            mintCost
        );
        _protocolFees(mintPower, count);
    }

    /** @notice claim a matured mint
     * @param id mint id
     */
    function claimMint(uint256 id) external dailyUpdate nonReentrant {
        _mintReward(_claimMint(_msgSender(), id, MintAction.CLAIM));
    }

    /** @notice batch claim matured mint of up to 100 claims per run
     */
    function batchClaimMint() external dailyUpdate nonReentrant {
        _mintReward(_batchClaimMint(_msgSender()));
    }

    /**** Stake Functions *****/
    /** @notice start a new stake
     * @param amount titan amount
     * @param numOfDays stake length
     */
    function startStake(uint256 amount, uint256 numOfDays) external dailyUpdate nonReentrant {
        if (balanceOf(_msgSender()) < amount) revert TitanX_InsufficientBalance();

        _burn(_msgSender(), amount);
        _initFirstSharesCycleIndex(
            _msgSender(),
            _startStake(
                _msgSender(),
                amount,
                numOfDays,
                getCurrentShareRate(),
                getCurrentContractDay(),
                getGlobalPayoutTriggered()
            )
        );
    }

    /** @notice end a stake
     * @param id stake id
     */
    function endStake(uint256 id) external dailyUpdate nonReentrant {
        _mint(
            _msgSender(),
            _endStake(
                _msgSender(),
                id,
                getCurrentContractDay(),
                StakeAction.END,
                StakeAction.END_OWN,
                getGlobalPayoutTriggered()
            )
        );
    }

    /** @notice end a stake for others
     * @param user wallet address
     * @param id stake id
     */
    function endStakeForOthers(address user, uint256 id) external dailyUpdate nonReentrant {
        _mint(
            user,
            _endStake(
                user,
                id,
                getCurrentContractDay(),
                StakeAction.END,
                StakeAction.END_OTHER,
                getGlobalPayoutTriggered()
            )
        );
    }

    /** @notice distribute the collected protocol fees into different pools/payouts
     * automatically send the incentive fee to caller, buyAndBurnFunds to BuyAndBurn contract, and genesis wallet
     */
    function distributeETH() external dailyUpdate nonReentrant {
        (uint256 incentiveFee, uint256 buyAndBurnFunds, uint256 genesisWallet) = _distributeETH();
        _sendFunds(incentiveFee, buyAndBurnFunds, genesisWallet);
    }

    /** @notice trigger cylce payouts for day 8, 28, 90, 369, 888 including the burn reward cycle 28
     * As long as the cycle has met its maturiy day (eg. Cycle8 is day 8), payout can be triggered in any day onwards
     */
    function triggerPayouts() external dailyUpdate nonReentrant {
        uint256 globalActiveShares = getGlobalShares() - getGlobalExpiredShares();
        if (globalActiveShares < 1) revert TitanX_NoSharesExist();

        uint256 incentiveFee;
        uint256 buyAndBurnFunds;
        uint256 genesisWallet;
        if (s_undistributedEth != 0)
            (incentiveFee, buyAndBurnFunds, genesisWallet) = _distributeETH();

        uint256 currentContractDay = getCurrentContractDay();
        PayoutTriggered isTriggered = PayoutTriggered.NO;
        _triggerCyclePayout(DAY8, globalActiveShares, currentContractDay) == PayoutTriggered.YES &&
            isTriggered == PayoutTriggered.NO
            ? isTriggered = PayoutTriggered.YES
            : isTriggered;
        _triggerCyclePayout(DAY28, globalActiveShares, currentContractDay) == PayoutTriggered.YES &&
            isTriggered == PayoutTriggered.NO
            ? isTriggered = PayoutTriggered.YES
            : isTriggered;
        _triggerCyclePayout(DAY90, globalActiveShares, currentContractDay) == PayoutTriggered.YES &&
            isTriggered == PayoutTriggered.NO
            ? isTriggered = PayoutTriggered.YES
            : isTriggered;
        _triggerCyclePayout(DAY369, globalActiveShares, currentContractDay) ==
            PayoutTriggered.YES &&
            isTriggered == PayoutTriggered.NO
            ? isTriggered = PayoutTriggered.YES
            : isTriggered;
        _triggerCyclePayout(DAY888, globalActiveShares, currentContractDay) ==
            PayoutTriggered.YES &&
            isTriggered == PayoutTriggered.NO
            ? isTriggered = PayoutTriggered.YES
            : isTriggered;

        if (isTriggered == PayoutTriggered.YES) {
            if (getGlobalPayoutTriggered() == PayoutTriggered.NO) _setGlobalPayoutTriggered();
        }

        if (incentiveFee != 0) _sendFunds(incentiveFee, buyAndBurnFunds, genesisWallet);
    }

    /** @notice claim all user available ETH payouts in one call */
    function claimUserAvailableETHPayouts() external dailyUpdate nonReentrant {
        uint256 reward = _claimCyclePayout(DAY8, PayoutClaim.SHARES);
        reward += _claimCyclePayout(DAY28, PayoutClaim.SHARES);
        reward += _claimCyclePayout(DAY90, PayoutClaim.SHARES);
        reward += _claimCyclePayout(DAY369, PayoutClaim.SHARES);
        reward += _claimCyclePayout(DAY888, PayoutClaim.SHARES);

        if (reward == 0) revert TitanX_NoCycleRewardToClaim();
        _sendViaCall(payable(_msgSender()), reward);
        emit RewardClaimed(_msgSender(), reward);
    }

    /** @notice claim all user available burn rewards in one call */
    function claimUserAvailableETHBurnPool() external dailyUpdate nonReentrant {
        uint256 reward = _claimCyclePayout(DAY28, PayoutClaim.BURN);
        if (reward == 0) revert TitanX_NoCycleRewardToClaim();
        _sendViaCall(payable(_msgSender()), reward);
        emit RewardClaimed(_msgSender(), reward);
    }

    /** @notice Set BuyAndBurn Contract Address - able to change to new contract that supports UniswapV4+
     * Only owner can call this function
     * @param contractAddress BuyAndBurn contract address
     */
    function setBuyAndBurnContractAddress(address contractAddress) external onlyOwner {
        if (contractAddress == address(0)) revert TitanX_InvalidAddress();
        s_buyAndBurnAddress = contractAddress;
    }

    /** @notice enable burn pool to start accumulate reward. Only owner can call this function. */
    function enableBurnPoolReward() external onlyOwner {
        s_burnPoolEnabled = BurnPoolEnabled.TRUE;
    }

    /** @notice Set to new genesis wallet. Only genesis wallet can call this function
     * @param newAddress new genesis wallet address
     */
    function setNewGenesisAddress(address newAddress) external {
        if (_msgSender() != s_genesisAddress) revert TitanX_NotAllowed();
        if (newAddress == address(0)) revert TitanX_InvalidAddress();
        s_genesisAddress = newAddress;
    }

    /** @notice mint initial LP tokens. Only BuyAndBurn contract set by genesis wallet can call this function
     */
    function mintLPTokens() external {
        if (_msgSender() != s_buyAndBurnAddress) revert TitanX_NotAllowed();
        if (s_initialLPMinted == InitialLPMinted.YES) revert TitanX_LPTokensHasMinted();
        s_initialLPMinted = InitialLPMinted.YES;
        _mint(s_buyAndBurnAddress, INITAL_LP_TOKENS);
    }

    /** @notice burn all BuyAndBurn contract Titan */
    function burnLPTokens() external dailyUpdate {
        _burn(s_buyAndBurnAddress, balanceOf(s_buyAndBurnAddress));
    }

    //private functions
    /** @dev mint reward to user and 1% to genesis wallet
     * @param reward titan amount
     */
    function _mintReward(uint256 reward) private {
        _mint(_msgSender(), reward);
        _mint(s_genesisAddress, (reward * 800) / PERCENT_BPS);
    }

    /** @dev send ETH to respective parties
     * @param incentiveFee fees for caller to run distributeETH()
     * @param buyAndBurnFunds funds for buy and burn
     * @param genesisWalletFunds funds for genesis wallet
     */
    function _sendFunds(
        uint256 incentiveFee,
        uint256 buyAndBurnFunds,
        uint256 genesisWalletFunds
    ) private {
        _sendViaCall(payable(_msgSender()), incentiveFee);
        _sendViaCall(payable(s_genesisAddress), genesisWalletFunds);
        _sendViaCall(payable(s_buyAndBurnAddress), buyAndBurnFunds);
    }

    /** @dev calculation to distribute collected protocol fees into different pools/parties */
    function _distributeETH()
        private
        returns (uint256 incentiveFee, uint256 buyAndBurnFunds, uint256 genesisWallet)
    {
        uint256 accumulatedFees = s_undistributedEth;
        if (accumulatedFees == 0) revert TitanX_EmptyUndistributeFees();
        s_undistributedEth = 0;
        emit ETHDistributed(_msgSender(), accumulatedFees);

        incentiveFee = (accumulatedFees * INCENTIVE_FEE_PERCENT) / INCENTIVE_FEE_PERCENT_BASE; //0.01%
        accumulatedFees -= incentiveFee;

        buyAndBurnFunds = (accumulatedFees * PERCENT_TO_BUY_AND_BURN) / PERCENT_BPS;
        uint256 cylceBurnReward = (accumulatedFees * PERCENT_TO_BURN_PAYOUTS) / PERCENT_BPS;
        genesisWallet = (accumulatedFees * PERCENT_TO_GENESIS) / PERCENT_BPS;
        uint256 cycleRewardPool = accumulatedFees -
            buyAndBurnFunds -
            cylceBurnReward -
            genesisWallet;

        if (s_burnPoolEnabled == BurnPoolEnabled.TRUE) s_cycleBurnReward += uint88(cylceBurnReward);
        else buyAndBurnFunds += cylceBurnReward;

        //cycle payout
        if (cycleRewardPool != 0) {
            uint256 cycle8Reward = (cycleRewardPool * CYCLE_8_PERCENT) / PERCENT_BPS;
            uint256 cycle28Reward = (cycleRewardPool * CYCLE_28_PERCENT) / PERCENT_BPS;
            uint256 cycle90Reward = (cycleRewardPool * CYCLE_90_PERCENT) / PERCENT_BPS;
            uint256 cycle369Reward = (cycleRewardPool * CYCLE_369_PERCENT) / PERCENT_BPS;
            _setCyclePayoutPool(DAY8, cycle8Reward);
            _setCyclePayoutPool(DAY28, cycle28Reward);
            _setCyclePayoutPool(DAY90, cycle90Reward);
            _setCyclePayoutPool(DAY369, cycle369Reward);
            _setCyclePayoutPool(
                DAY888,
                cycleRewardPool - cycle8Reward - cycle28Reward - cycle90Reward - cycle369Reward
            );
        }
    }

    /** @dev calcualte required protocol fees, and return the balance (if any)
     * @param mintPower mint power 1-100
     * @param count how many mints
     */
    function _protocolFees(uint256 mintPower, uint256 count) private {
        uint256 protocolFee;

        protocolFee = getBatchMintCost(mintPower, count, getCurrentMintCost());
        if (msg.value < protocolFee) revert TitanX_InsufficientProtocolFees();

        uint256 feeBalance;
        s_undistributedEth += uint88(protocolFee);
        feeBalance = msg.value - protocolFee;

        if (feeBalance != 0) {
            _sendViaCall(payable(_msgSender()), feeBalance);
        }

        emit ProtocolFeeRecevied(_msgSender(), getCurrentContractDay(), protocolFee);
    }

    /** @dev calculate payouts for each cycle day tracked by cycle index
     * @param cycleNo cylce day 8, 28, 90, 369, 888
     * @param globalActiveShares global active shares
     * @param currentContractDay current contract day
     * @return triggered is payout triggered succesfully
     */
    function _triggerCyclePayout(
        uint256 cycleNo,
        uint256 globalActiveShares,
        uint256 currentContractDay
    ) private returns (PayoutTriggered triggered) {
        //check against cylce payout maturity day
        if (currentContractDay < getNextCyclePayoutDay(cycleNo)) return PayoutTriggered.NO;

        //update the next cycle payout day regardless of payout triggered succesfully or not
        _setNextCyclePayoutDay(cycleNo);

        uint256 reward = getCyclePayoutPool(cycleNo);
        if (reward == 0) return PayoutTriggered.NO;

        //calculate cycle reward per share and get new cycle Index
        uint256 cycleIndex = _calculateCycleRewardPerShare(cycleNo, reward, globalActiveShares);

        //calculate burn reward if cycle is 28
        uint256 totalCycleBurn = getCycleBurnTotal(cycleIndex);
        uint256 burnReward;
        if (cycleNo == DAY28 && totalCycleBurn != 0) {
            burnReward = s_cycleBurnReward;
            if (burnReward != 0) {
                s_cycleBurnReward = 0;
                _calculateCycleBurnRewardPerToken(cycleIndex, burnReward, totalCycleBurn);
            }
        }

        emit CyclePayoutTriggered(_msgSender(), cycleNo, reward, burnReward);

        return PayoutTriggered.YES;
    }

    /** @dev calculate user reward with specified cycle day and claim type (shares/burn) and update user's last claim cycle index
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @param payoutClaim claim type - (Shares=0/Burn=1)
     */
    function _claimCyclePayout(uint256 cycleNo, PayoutClaim payoutClaim) private returns (uint256) {
        (
            uint256 reward,
            uint256 userClaimCycleIndex,
            uint256 userClaimSharesIndex,
            uint256 userClaimBurnCycleIndex
        ) = _calculateUserCycleReward(_msgSender(), cycleNo, payoutClaim);

        if (payoutClaim == PayoutClaim.SHARES)
            _updateUserClaimIndexes(
                _msgSender(),
                cycleNo,
                userClaimCycleIndex,
                userClaimSharesIndex
            );
        if (payoutClaim == PayoutClaim.BURN) {
            _updateUserBurnCycleClaimIndex(_msgSender(), cycleNo, userClaimBurnCycleIndex);
        }

        return reward;
    }

    /** @dev burn liquid Titan through other project.
     * called by other contracts for proof of burn 2.0 with up to 8% for both builder fee and user rebate
     * @param user user address
     * @param amount liquid titan amount
     * @param userRebatePercentage percentage for user rebate in liquid titan (0 - 8)
     * @param rewardPaybackPercentage percentage for builder fee in liquid titan (0 - 8)
     * @param rewardPaybackAddress builder can opt to receive fee in another address
     */
    function _burnLiquidTitan(
        address user,
        uint256 amount,
        uint256 userRebatePercentage,
        uint256 rewardPaybackPercentage,
        address rewardPaybackAddress
    ) private {
        if (amount == 0) revert TitanX_InvalidAmount();
        if (balanceOf(user) < amount) revert TitanX_InsufficientBalance();
        _spendAllowance(user, _msgSender(), amount);
        _burnbefore(userRebatePercentage, rewardPaybackPercentage);
        _burn(user, amount);
        _burnAfter(
            user,
            amount,
            userRebatePercentage,
            rewardPaybackPercentage,
            rewardPaybackAddress,
            BurnSource.LIQUID
        );
    }

    /** @dev burn stake through other project.
     * called by other contracts for proof of burn 2.0 with up to 8% for both builder fee and user rebate
     * @param user user address
     * @param id stake id
     * @param userRebatePercentage percentage for user rebate in liquid titan (0 - 8)
     * @param rewardPaybackPercentage percentage for builder fee in liquid titan (0 - 8)
     * @param rewardPaybackAddress builder can opt to receive fee in another address
     */
    function _burnStake(
        address user,
        uint256 id,
        uint256 userRebatePercentage,
        uint256 rewardPaybackPercentage,
        address rewardPaybackAddress
    ) private {
        _spendBurnStakeAllowance(user);
        _burnbefore(userRebatePercentage, rewardPaybackPercentage);
        _burnAfter(
            user,
            _endStake(
                user,
                id,
                getCurrentContractDay(),
                StakeAction.BURN,
                StakeAction.END_OWN,
                getGlobalPayoutTriggered()
            ),
            userRebatePercentage,
            rewardPaybackPercentage,
            rewardPaybackAddress,
            BurnSource.STAKE
        );
    }

    /** @dev burn mint through other project.
     * called by other contracts for proof of burn 2.0
     * burn mint has no builder reward and no user rebate
     * @param user user address
     * @param id mint id
     */
    function _burnMint(address user, uint256 id) private {
        _spendBurnMintAllowance(user);
        _burnbefore(0, 0);
        uint256 amount = _claimMint(user, id, MintAction.BURN);
        _mint(s_genesisAddress, (amount * 800) / PERCENT_BPS);
        _burnAfter(user, amount, 0, 0, _msgSender(), BurnSource.MINT);
    }

    /** @dev perform checks before burning starts.
     * check reward percentage and check if called by supported contract
     * @param userRebatePercentage percentage for user rebate
     * @param rewardPaybackPercentage percentage for builder fee
     */
    function _burnbefore(
        uint256 userRebatePercentage,
        uint256 rewardPaybackPercentage
    ) private view {
        if (rewardPaybackPercentage + userRebatePercentage > MAX_BURN_REWARD_PERCENT)
            revert TitanX_InvalidBurnRewardPercent();

        //Only supported contracts is allowed to call this function
        if (
            !IERC165(_msgSender()).supportsInterface(IERC165.supportsInterface.selector) ||
            !IERC165(_msgSender()).supportsInterface(type(ITitanOnBurn).interfaceId)
        ) revert TitanX_NotSupportedContract();
    }

    /** @dev update burn stats and mint reward to builder or user if applicable
     * @param user user address
     * @param amount titan amount burned
     * @param userRebatePercentage percentage for user rebate in liquid titan (0 - 8)
     * @param rewardPaybackPercentage percentage for builder fee in liquid titan (0 - 8)
     * @param rewardPaybackAddress builder can opt to receive fee in another address
     * @param source liquid/mint/stake
     */
    function _burnAfter(
        address user,
        uint256 amount,
        uint256 userRebatePercentage,
        uint256 rewardPaybackPercentage,
        address rewardPaybackAddress,
        BurnSource source
    ) private {
        uint256 index = getCurrentCycleIndex(DAY28) + 1;
        /** set to the latest cylceIndex + 1 for fresh wallet
         * same concept as _initFirstSharesCycleIndex, refer to its dev comment  */
        if (getUserBurnTotal(user) == 0) _updateUserBurnCycleClaimIndex(user, DAY28, index);
        _updateBurnAmount(user, _msgSender(), amount, index, source);

        uint256 devFee;
        uint256 userRebate;
        if (rewardPaybackPercentage != 0)
            devFee = (amount * rewardPaybackPercentage * PERCENT_BPS) / (100 * PERCENT_BPS);
        if (userRebatePercentage != 0)
            userRebate = (amount * userRebatePercentage * PERCENT_BPS) / (100 * PERCENT_BPS);

        if (devFee != 0) _mint(rewardPaybackAddress, devFee);
        if (userRebate != 0) _mint(user, userRebate);

        ITitanOnBurn(_msgSender()).onBurn(user, amount);
    }

    /** @dev Recommended method to use to send native coins.
     * @param to receiving address.
     * @param amount in wei.
     */
    function _sendViaCall(address payable to, uint256 amount) private {
        if (to == address(0)) revert TitanX_InvalidAddress();
        (bool sent, ) = to.call{value: amount}("");
        if (!sent) revert TitanX_FailedToSendAmount();
    }

    /** @dev reduce user's allowance for caller (spender/project) by 1 (burn 1 stake at a time)
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     * @param user user address
     */
    function _spendBurnStakeAllowance(address user) private {
        uint256 currentAllowance = allowanceBurnStakes(user, _msgSender());
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance == 0) revert TitanX_InsufficientBurnAllowance();
            --s_allowanceBurnStakes[user][_msgSender()];
        }
    }

    /** @dev reduce user's allowance for caller (spender/project) by 1 (burn 1 mint at a time)
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     * @param user user address
     */
    function _spendBurnMintAllowance(address user) private {
        uint256 currentAllowance = allowanceBurnMints(user, _msgSender());
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance == 0) revert TitanX_InsufficientBurnAllowance();
            --s_allowanceBurnMints[user][_msgSender()];
        }
    }

    //Views
    /** @dev calculate user payout reward with specified cycle day and claim type (shares/burn).
     * it loops through all the unclaimed cylce index until the latest cycle index
     * @param user user address
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @param payoutClaim claim type (Shares=0/Burn=1)
     * @return rewards calculated reward
     * @return userClaimCycleIndex last claim cycle index
     * @return userClaimSharesIndex last claim shares index
     * @return userClaimBurnCycleIndex last claim burn cycle index
     */
    function _calculateUserCycleReward(
        address user,
        uint256 cycleNo,
        PayoutClaim payoutClaim
    )
        private
        view
        returns (
            uint256 rewards,
            uint256 userClaimCycleIndex,
            uint256 userClaimSharesIndex,
            uint256 userClaimBurnCycleIndex
        )
    {
        uint256 cycleMaxIndex = getCurrentCycleIndex(cycleNo);

        if (payoutClaim == PayoutClaim.SHARES) {
            (userClaimCycleIndex, userClaimSharesIndex) = getUserLastClaimIndex(user, cycleNo);
            uint256 sharesMaxIndex = getUserLatestShareIndex(user);

            for (uint256 i = userClaimCycleIndex; i <= cycleMaxIndex; i++) {
                (uint256 payoutPerShare, uint256 payoutDay) = getPayoutPerShare(cycleNo, i);
                uint256 shares;

                //loop shares indexes to find the last updated shares before/same triggered payout day
                for (uint256 j = userClaimSharesIndex; j <= sharesMaxIndex; j++) {
                    if (getUserActiveSharesDay(user, j) <= payoutDay)
                        shares = getUserActiveShares(user, j);
                    else break;

                    userClaimSharesIndex = j;
                }

                if (payoutPerShare != 0 && shares != 0) {
                    //reward has 18 decimals scaling, so here divide by 1e18
                    rewards += (shares * payoutPerShare) / SCALING_FACTOR_1e18;
                }

                userClaimCycleIndex = i + 1;
            }
        } else if (cycleNo == DAY28 && payoutClaim == PayoutClaim.BURN) {
            userClaimBurnCycleIndex = getUserLastBurnClaimIndex(user, cycleNo);
            for (uint256 i = userClaimBurnCycleIndex; i <= cycleMaxIndex; i++) {
                uint256 burnPayoutPerToken = getCycleBurnPayoutPerToken(i);
                rewards += (burnPayoutPerToken != 0)
                    ? (burnPayoutPerToken * _getUserCycleBurnTotal(user, i)) / SCALING_FACTOR_1e18
                    : 0;
                userClaimBurnCycleIndex = i + 1;
            }
        }
    }

    /** @notice get contract ETH balance
     * @return balance eth balance
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /** @notice get undistributed ETH balance
     * @return amount eth amount
     */
    function getUndistributedEth() public view returns (uint256) {
        return s_undistributedEth;
    }

    /** @notice get user ETH payout for all cycles
     * @param user user address
     * @return reward total reward
     */
    function getUserETHClaimableTotal(address user) public view returns (uint256 reward) {
        uint256 _reward;
        (_reward, , , ) = _calculateUserCycleReward(user, DAY8, PayoutClaim.SHARES);
        reward += _reward;
        (_reward, , , ) = _calculateUserCycleReward(user, DAY28, PayoutClaim.SHARES);
        reward += _reward;
        (_reward, , , ) = _calculateUserCycleReward(user, DAY90, PayoutClaim.SHARES);
        reward += _reward;
        (_reward, , , ) = _calculateUserCycleReward(user, DAY369, PayoutClaim.SHARES);
        reward += _reward;
        (_reward, , , ) = _calculateUserCycleReward(user, DAY888, PayoutClaim.SHARES);
        reward += _reward;
    }

    /** @notice get user burn reward ETH payout
     * @param user user address
     * @return reward burn reward
     */
    function getUserBurnPoolETHClaimableTotal(address user) public view returns (uint256 reward) {
        (reward, , , ) = _calculateUserCycleReward(user, DAY28, PayoutClaim.BURN);
    }

    /** @notice get total penalties from mint and stake
     * @return amount total penalties
     */
    function getTotalPenalties() public view returns (uint256) {
        return getTotalMintPenalty() + getTotalStakePenalty();
    }

    /** @notice get burn pool reward
     * @return reward burn pool reward
     */
    function getCycleBurnPool() public view returns (uint256) {
        return s_cycleBurnReward;
    }

    /** @notice get user current burn cycle percentage
     * @return percentage in 18 decimals
     */
    function getCurrentUserBurnCyclePercentage() public view returns (uint256) {
        uint256 index = getCurrentCycleIndex(DAY28) + 1;
        uint256 cycleBurnTotal = getCycleBurnTotal(index);
        return
            cycleBurnTotal == 0
                ? 0
                : (_getUserCycleBurnTotal(_msgSender(), index) * 100 * SCALING_FACTOR_1e18) /
                    cycleBurnTotal;
    }

    /** @notice get user current cycle total titan burned
     * @param user user address
     * @return burnTotal total titan burned in curreny burn cycle
     */
    function getUserCycleBurnTotal(address user) public view returns (uint256) {
        return _getUserCycleBurnTotal(user, getCurrentCycleIndex(DAY28) + 1);
    }

    function isBurnPoolEnabled() public view returns (BurnPoolEnabled) {
        return s_burnPoolEnabled;
    }

    /** @notice returns user's burn stakes allowance of a project
     * @param user user address
     * @param spender project address
     */
    function allowanceBurnStakes(address user, address spender) public view returns (uint256) {
        return s_allowanceBurnStakes[user][spender];
    }

    /** @notice returns user's burn mints allowance of a project
     * @param user user address
     * @param spender project address
     */
    function allowanceBurnMints(address user, address spender) public view returns (uint256) {
        return s_allowanceBurnMints[user][spender];
    }

    //Public functions for devs to intergrate with Titan
    /** @notice allow anyone to sync dailyUpdate manually */
    function manualDailyUpdate() public dailyUpdate {}

    /** @notice Burn Titan tokens and creates Proof-Of-Burn record to be used by connected DeFi and fee is paid to specified address
     * @param user user address
     * @param amount titan amount
     * @param userRebatePercentage percentage for user rebate in liquid titan (0 - 8)
     * @param rewardPaybackPercentage percentage for builder fee in liquid titan (0 - 8)
     * @param rewardPaybackAddress builder can opt to receive fee in another address
     */
    function burnTokensToPayAddress(
        address user,
        uint256 amount,
        uint256 userRebatePercentage,
        uint256 rewardPaybackPercentage,
        address rewardPaybackAddress
    ) public dailyUpdate nonReentrant {
        _burnLiquidTitan(
            user,
            amount,
            userRebatePercentage,
            rewardPaybackPercentage,
            rewardPaybackAddress
        );
    }

    /** @notice Burn Titan tokens and creates Proof-Of-Burn record to be used by connected DeFi and fee is paid to specified address
     * @param user user address
     * @param amount titan amount
     * @param userRebatePercentage percentage for user rebate in liquid titan (0 - 8)
     * @param rewardPaybackPercentage percentage for builder fee in liquid titan (0 - 8)
     */
    function burnTokens(
        address user,
        uint256 amount,
        uint256 userRebatePercentage,
        uint256 rewardPaybackPercentage
    ) public dailyUpdate nonReentrant {
        _burnLiquidTitan(user, amount, userRebatePercentage, rewardPaybackPercentage, _msgSender());
    }

    /** @notice allows user to burn liquid titan directly from contract
     * @param amount titan amount
     */
    function userBurnTokens(uint256 amount) public dailyUpdate nonReentrant {
        if (amount == 0) revert TitanX_InvalidAmount();
        if (balanceOf(_msgSender()) < amount) revert TitanX_InsufficientBalance();
        _burn(_msgSender(), amount);
        _updateBurnAmount(
            _msgSender(),
            address(0),
            amount,
            getCurrentCycleIndex(DAY28) + 1,
            BurnSource.LIQUID
        );
    }

    /** @notice Burn stake and creates Proof-Of-Burn record to be used by connected DeFi and fee is paid to specified address
     * @param user user address
     * @param id stake id
     * @param userRebatePercentage percentage for user rebate in liquid titan (0 - 8)
     * @param rewardPaybackPercentage percentage for builder fee in liquid titan (0 - 8)
     * @param rewardPaybackAddress builder can opt to receive fee in another address
     */
    function burnStakeToPayAddress(
        address user,
        uint256 id,
        uint256 userRebatePercentage,
        uint256 rewardPaybackPercentage,
        address rewardPaybackAddress
    ) public dailyUpdate nonReentrant {
        _burnStake(user, id, userRebatePercentage, rewardPaybackPercentage, rewardPaybackAddress);
    }

    /** @notice Burn stake and creates Proof-Of-Burn record to be used by connected DeFi and fee is paid to project contract address
     * @param user user address
     * @param id stake id
     * @param userRebatePercentage percentage for user rebate in liquid titan (0 - 8)
     * @param rewardPaybackPercentage percentage for builder fee in liquid titan (0 - 8)
     */
    function burnStake(
        address user,
        uint256 id,
        uint256 userRebatePercentage,
        uint256 rewardPaybackPercentage
    ) public dailyUpdate nonReentrant {
        _burnStake(user, id, userRebatePercentage, rewardPaybackPercentage, _msgSender());
    }

    /** @notice allows user to burn stake directly from contract
     * @param id stake id
     */
    function userBurnStake(uint256 id) public dailyUpdate nonReentrant {
        _updateBurnAmount(
            _msgSender(),
            address(0),
            _endStake(
                _msgSender(),
                id,
                getCurrentContractDay(),
                StakeAction.BURN,
                StakeAction.END_OWN,
                getGlobalPayoutTriggered()
            ),
            getCurrentCycleIndex(DAY28) + 1,
            BurnSource.STAKE
        );
    }

    /** @notice Burn mint and creates Proof-Of-Burn record to be used by connected DeFi.
     * Burn mint has no project reward or user rebate
     * @param user user address
     * @param id mint id
     */
    function burnMint(address user, uint256 id) public dailyUpdate nonReentrant {
        _burnMint(user, id);
    }

    /** @notice allows user to burn mint directly from contract
     * @param id mint id
     */
    function userBurnMint(uint256 id) public dailyUpdate nonReentrant {
        _updateBurnAmount(
            _msgSender(),
            address(0),
            _claimMint(_msgSender(), id, MintAction.BURN),
            getCurrentCycleIndex(DAY28) + 1,
            BurnSource.MINT
        );
    }

    /** @notice Sets `amount` as the allowance of `spender` over the caller's (user) mints.
     * @param spender contract address
     * @param amount allowance amount
     */
    function approveBurnMints(address spender, uint256 amount) public returns (bool) {
        if (spender == address(0)) revert TitanX_InvalidAddress();
        s_allowanceBurnMints[_msgSender()][spender] = amount;
        emit ApproveBurnMints(_msgSender(), spender, amount);
        return true;
    }

    /** @notice Sets `amount` as the allowance of `spender` over the caller's (user) stakes.
     * @param spender contract address
     * @param amount allowance amount
     */
    function approveBurnStakes(address spender, uint256 amount) public returns (bool) {
        if (spender == address(0)) revert TitanX_InvalidAddress();
        s_allowanceBurnStakes[_msgSender()][spender] = amount;
        emit ApproveBurnStakes(_msgSender(), spender, amount);
        return true;
    }
}
