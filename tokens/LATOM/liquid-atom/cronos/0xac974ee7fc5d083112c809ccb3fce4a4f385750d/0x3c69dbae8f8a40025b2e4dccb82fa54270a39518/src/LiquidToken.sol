// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./UUPSUpgradeableWithDelay.sol";
import "./interfaces/ILiquidToken.sol";
import "./LiquidTokenStorage.sol";

abstract contract LiquidToken is
    ILiquidToken,
    ERC20Upgradeable,
    UUPSUpgradeableWithDelay,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    LiquidTokenStorage
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    /// @notice Emitted when user stake token
    event Stake(address indexed receiver, uint256 tokenAmount, uint256 shareAmount);

    /// @notice Emitted when a user request to unbond their staked token
    event RequestUnbond(
        address indexed receiver,
        uint256 indexed tokenId,
        uint256 shareAmount,
        uint256 liquidToken2TokenExchangeRate,
        uint256 batchNo
    );

    /// @notice Emitted when a user redeems the NFT for token
    event Unbond(
        address indexed receiver,
        uint256 indexed tokenId,
        uint256 tokenAmount,
        uint256 tokenFeeAmount
    );

    /// @notice Emitted when the bot has an update for an unbonding batch
    event SetUnbondingBatchStatus(uint256 batchNo, UnbondingStatus status);

    /// @notice Emitted when the bot claim reward on a comos chain
    event AccrueReward(uint256 indexed amount, string indexed txnHash);

    /// @notice Emitted when a slash happen on unbonding request
    event SlashRequest(uint256 tokenId, uint256 oldExchangeRate, uint256 newExchangeRate);

    /// @notice Emitted when a slash happen on a comos chain
    event Slash(string indexed validatorAddress, uint256 indexed amount, uint256 time);

    /// @notice Emitted when a new bridge destination on a comos chain is set
    event SetBridgeDestination(string oldDestination, string newDestination);

    /// @notice Emitted when the token is bridged over to a comos chain
    event Bridge(uint256 amount);

    /// @notice Emitted when token is bridged from a comos chain back to contract
    event Deposit(uint256 amount);

    /// @notice Emitted when new unbonding fee is set
    event SetUnbondingFee(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when new treasury is set
    event SetTreasury(address oldTreasury, address newTreasury);

    /// @notice Emitted when new ibc receiver is set
    event SetIBCReceiver(address oldReceiver, address newReceiver);

    /// @notice Emitted when the unbonding duration is updated
    event SetUnbondingDuration(uint256 oldUnbondingDuration, uint256 newUnbondingDuration);

    // @notice Emitted when unbonding processing time is updated
    event SetUnbondingMaxProcessingTime(
        uint256 oldUnbondingMaxProcessingDuration,
        uint256 newUnbondingMaxProcessingDuration
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @param _venoNft NFT address
     * @param _token on cronos with IBC method to bridge to other cosmos chain
     * @param _ibcReceiver IBC fund from comsmos chain are IBC to here
     * @param _treasury Withdrawal fee will be sent here
     * @param _upgradeDelay Time to wait before new upgrade implementation
     * @param _name Name of token eg. "Liquid CRO"
     * @param _symbol Symbol of token eg. "LCRO"
     * @param _unbondingProcessingTime time taken to process unbonding
     * @param _unbondingDuration time taken to unbond, eg. 28 days for crypto.org, 21 days for cosmos
     */
    function initialize(
        IVenoNft _venoNft,
        IToken _token,
        IIBCReceiver _ibcReceiver,
        address _treasury,
        uint256 _upgradeDelay,
        string memory _name,
        string memory _symbol,
        uint256 _unbondingProcessingTime,
        uint256 _unbondingDuration
    ) public initializer {
        require(address(_venoNft) != address(0), "venoNft addresss zero");
        require(address(_token) != address(0), "token address zero");
        require(address(_ibcReceiver) != address(0), "ibcReceiver address zero");
        require(_treasury != address(0), "treasury address zero");
        require(_upgradeDelay > 0, "upgradeDelay is zero");

        venoNft = _venoNft;
        token = _token;
        ibcReceiver = _ibcReceiver;
        treasury = _treasury;

        // Default 0.2%
        unbondingFee = 200;

        // Example: Crypto.org - 28 days. Cosmos - 21 days.
        unbondingDuration = _unbondingDuration;

        // Example for LiquidCro - 4 days + 12 hours.
        // 4 days from max 7 concurrent unbonding request over 28 days
        // 12 hours for bot to process unbonding and bot to IBC the token back after unbonding
        // When the protocol is stable, the 12 hours can be reduced gradually
        unbondingProcessingTime = _unbondingProcessingTime;

        // Set batch 0 as pending status
        batch2UnbondingStatus[currentUnbondingBatchNo] = UnbondingStatus.PENDING_BOT;

        __ERC20_init(_name, _symbol);
        __UUPSUpgradeableWithDelay_init(_upgradeDelay);
        __Pausable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice LiquidToken should have the same decimals as token. User would be able to understand
     *         1:1 relationship instead of 1:0.000001 (if decimals are different)
     */
    function decimals() public view override returns (uint8) {
        return token.decimals();
    }

    /**
     * @dev override if there's a MAX decimal required like LiquidCro
     */
    function stake(
        address _receiver,
        uint256 _amount
    ) external virtual override nonReentrant whenNotPaused returns (uint256) {
        require(_receiver != address(0), "ZERO_ADDRESS");
        require(_amount > 0, "ZERO_DEPOSIT");

        token.transferFrom(msg.sender, address(this), _amount);
        uint256 shareAmount = convertToShare(_amount);

        _mint(_receiver, shareAmount);

        totalPooledToken += _amount;
        totalTokenToBridge += _amount;

        emit Stake(_receiver, _amount, shareAmount);
        return shareAmount;
    }

    function requestUnbond(
        uint256 _shareAmount,
        address _receiver
    ) external virtual override nonReentrant whenNotPaused returns (uint256) {
        require(_receiver != address(0), "ZERO_ADDRESS");
        require(_shareAmount > 0, "ZERO_SHAREAMOUNT");

        uint256 unlockTime = getUnbondUnlockDate();
        uint256 tokenId = venoNft.mint(_receiver);
        unbondRequests.add(tokenId);

        uint256 liquidToken2TokenExchangeRate = (totalPooledToken * EXCHANGE_RATE_PRECISION) / totalSupply();
        token2UnbondRequest[tokenId] = UnbondRequest({
            unlockStartTime: uint128(block.timestamp),
            unlockEndTime: uint128(unlockTime),
            liquidTokenAmount: _shareAmount,
            liquidToken2TokenExchangeRate: liquidToken2TokenExchangeRate,
            batchNo: currentUnbondingBatchNo
        });

        // Reduce totalPooledToken in protocol and burn share
        totalPooledToken -= (_shareAmount * liquidToken2TokenExchangeRate) / EXCHANGE_RATE_PRECISION;
        _burn(msg.sender, _shareAmount);

        emit RequestUnbond(
            _receiver,
            tokenId,
            _shareAmount,
            liquidToken2TokenExchangeRate,
            currentUnbondingBatchNo
        );
        return tokenId;
    }

    function batchUnbond(
        uint256[] calldata _tokenIds,
        address _receiver
    ) external virtual override returns (uint256) {
        uint256 totalTokenAmt;
        for (uint256 i; i < _tokenIds.length; i++) {
            totalTokenAmt += unbond(_tokenIds[i], _receiver);
        }

        return totalTokenAmt;
    }

    function unbond(
        uint256 _tokenId,
        address _receiver
    ) public virtual override nonReentrant whenNotPaused returns (uint256) {
        require(_receiver != address(0), "ZERO_ADDRESS");
        require(venoNft.isApprovedOrOwner(msg.sender, _tokenId), "NOT_OWNER");

        UnbondRequest storage unbondRequest = token2UnbondRequest[_tokenId];
        require(unbondRequest.unlockEndTime <= block.timestamp, "NOT_UNLOCK_YET");

        UnbondingStatus status = batch2UnbondingStatus[unbondRequest.batchNo];
        require(status == UnbondingStatus.UNBONDED, "NOT_UNBONDED_YET");

        // Collect any pending token - this would prevent a situation where fund are in IBCReceiver
        // and the bot have not take the fund over
        if (token.balanceOf(address(ibcReceiver)) > 0) {
            ibcReceiver.transfer();
        }

        // Burn NFT
        venoNft.burn(_tokenId);
        unbondRequests.remove(_tokenId);

        uint256 totalTokenAmount = (unbondRequest.liquidTokenAmount *
            unbondRequest.liquidToken2TokenExchangeRate) / EXCHANGE_RATE_PRECISION;

        // Send token fee amount to treasury
        uint256 tokenFeeAmount = (totalTokenAmount * unbondingFee) / UNBONDING_FEE_DENOMINATOR;
        token.transfer(treasury, tokenFeeAmount);

        // Send token amount to user
        uint256 tokenAmount = totalTokenAmount - tokenFeeAmount;
        token.transfer(_receiver, tokenAmount);

        emit Unbond(_receiver, _tokenId, tokenAmount, tokenFeeAmount);
        return tokenAmount;
    }

    /*********************************************************************************
     *                                                                               *
     *                    BOT AND ADMIN-ONLY FUNCTIONS                               *
     *                                                                               *
     *********************************************************************************/

    function accrueReward(uint256 amount, string calldata txnHash) external override onlyRole(ROLE_BOT) {
        require(amount > 0, "ZERO_AMOUNT");
        require(txnHash2AccrueRewardAmount[txnHash] == 0, "ACCRUE_RECORDED");

        totalPooledToken += amount;
        txnHash2AccrueRewardAmount[txnHash] = amount;

        emit AccrueReward(amount, txnHash);
    }

    /**
     * @dev Override in implementation since CRC20/CRC21 has different methods to call for bridging
     */
    function bridge(uint256 amount) external virtual;

    function setUnbondingBatchStatus(uint256 _batchNo, UnbondingStatus _status) external onlyRole(ROLE_BOT) {
        require(_status != UnbondingStatus.PENDING_BOT, "PENDING_BOT set by contract only");
        require(_batchNo <= currentUnbondingBatchNo, "Cannot set future batch");
        UnbondingStatus batchStatus = batch2UnbondingStatus[_batchNo];

        if (_status == UnbondingStatus.PROCESSING) {
            // Processing - When bot started to process the unbonding requests
            require(_batchNo == currentUnbondingBatchNo, "Should process only current batch number");
            require(batchStatus == UnbondingStatus.PENDING_BOT, "batchStatus should be PENDING_BOT");

            if (_batchNo > 0) {
                // theres a previous batch, double check previous batch status is unbonding or unbonded
                UnbondingStatus prevStatus = batch2UnbondingStatus[_batchNo - 1];
                require(
                    prevStatus == UnbondingStatus.UNBONDING || prevStatus == UnbondingStatus.UNBONDED,
                    "previous batch should be unbonding or unbonded"
                );
            }

            // new unbonding request will be in next batch
            currentUnbondingBatchNo += 1;

            batch2UnbondingStatus[_batchNo] = UnbondingStatus.PROCESSING;
            emit SetUnbondingBatchStatus(_batchNo, UnbondingStatus.PROCESSING);

            // Set the new batch to PENDING_BOT status
            batch2UnbondingStatus[currentUnbondingBatchNo] = UnbondingStatus.PENDING_BOT;
            emit SetUnbondingBatchStatus(currentUnbondingBatchNo, UnbondingStatus.PENDING_BOT);
        } else if (_status == UnbondingStatus.UNBONDING) {
            // Unbonding - When bot has successfully informed validator to start unbonding
            require(batchStatus == UnbondingStatus.PROCESSING, "batchStatus should be PROCESSING");

            // Also update lastUnbondTime
            lastUnbondTime = block.timestamp;

            batch2UnbondingStatus[_batchNo] = UnbondingStatus.UNBONDING;
            emit SetUnbondingBatchStatus(_batchNo, UnbondingStatus.UNBONDING);
        } else if (_status == UnbondingStatus.UNBONDED) {
            // UNBONDED - When bot has IBC the fund for the batch back to cronos
            require(batchStatus == UnbondingStatus.UNBONDING, "batchStatus should be UNBONDING");

            batch2UnbondingStatus[_batchNo] = UnbondingStatus.UNBONDED;
            emit SetUnbondingBatchStatus(_batchNo, UnbondingStatus.UNBONDED);
        }
    }

    function pauseDueSlashing() external onlyRole(ROLE_BOT) {
        _pause();
    }

    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused() ? _unpause() : _pause();
    }

    function slashUnbondingRequests(
        uint256[] calldata _tokenIds,
        uint256[] calldata _newRates
    ) external onlyRole(ROLE_SLASHER) {
        require(_tokenIds.length == _newRates.length, "Both input length must match");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            UnbondRequest storage request = token2UnbondRequest[_tokenIds[i]];
            require(request.liquidToken2TokenExchangeRate > _newRates[i], "New exchange rate must be lower");
            require(
                (request.liquidToken2TokenExchangeRate * 9) / 10 <= _newRates[i],
                "New exchange rate cannot drop more than 10 percent"
            );

            uint256 oldRate = request.liquidToken2TokenExchangeRate;
            request.liquidToken2TokenExchangeRate = _newRates[i];

            emit SlashRequest(_tokenIds[i], oldRate, _newRates[i]);
        }
    }

    /**
     * @dev see interface on detailed instruction, only execute this after calculating how much
     *      token to slash between unbonding users / protocol (both parties should slash by equal percentage)
     */
    function slash(
        string calldata _validatorAddress,
        uint256 _amount,
        uint256 _time
    ) external override onlyRole(ROLE_SLASHER) {
        require(validator2Time2AmountSlashed[_validatorAddress][_time] == 0, "SLASH_RECORDED");
        require(_amount > 0, "ZERO_AMOUNT");
        // totalPooledToken cannot go to 0, otherwise convertToShare will not mint the correct share for new stakers
        require(_amount < totalPooledToken, "amount must be less than totalPooledToken");

        validator2Time2AmountSlashed[_validatorAddress][_time] = _amount;
        totalPooledToken -= _amount;

        emit Slash(_validatorAddress, _amount, _time);
    }

    function setBridgeDestination(string memory _destination) external onlyRole(DEFAULT_ADMIN_ROLE) {
        //TODO: potentially better validation on destination
        require(bytes(_destination).length > 0, "EMPTY_DESTINATION");

        string memory oldDestination = bridgeDestination;
        bridgeDestination = _destination;
        emit SetBridgeDestination(oldDestination, _destination);
    }

    /**
     * @param _unbondingFee - 100 = 0.1%
     */
    function setUnbondingFee(uint256 _unbondingFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_unbondingFee <= 1000, "Fee must be 1% or lower");

        uint256 oldUnbondingFee = unbondingFee;
        unbondingFee = _unbondingFee;
        emit SetUnbondingFee(oldUnbondingFee, unbondingFee);
    }

    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "EMPTY_ADDRESS");

        address oldTreasury = treasury;
        treasury = _treasury;
        emit SetTreasury(oldTreasury, treasury);
    }

    function setIBCReceiver(address _ibcReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_ibcReceiver != address(0), "EMPTY_ADDRESS");

        address oldIbcReceiver = address(ibcReceiver);
        ibcReceiver = IIBCReceiver(_ibcReceiver);
        emit SetIBCReceiver(oldIbcReceiver, _ibcReceiver);
    }

    /**
     * @dev only called if the targetted cosmos chain has a new proposal which changes the unbonding duration
     */
    function setUnbondingDuration(uint256 _unbondingDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_unbondingDuration <= 28 days, "_unbondingDuration is too high");

        uint256 oldUnbondingDuration = unbondingDuration;
        unbondingDuration = _unbondingDuration;

        emit SetUnbondingDuration(oldUnbondingDuration, _unbondingDuration);
    }

    /**
     * @dev Set unbonding processing time. Together with unbondingDuration, they will be used to
     *      estimate the unlock time for user's unbonding request. This value might be tweaked based
     *      on how stable IBC and bot are to avoid under-promising the user the unlock time.
     */
    function setUnbondingProcessingTime(
        uint256 _unbondingProcessingTime
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_unbondingProcessingTime <= 7 days, "_unbondingProcessingTime is too high");

        uint256 oldUnbondingProcessingTime = unbondingProcessingTime;
        unbondingProcessingTime = _unbondingProcessingTime;

        emit SetUnbondingMaxProcessingTime(oldUnbondingProcessingTime, _unbondingProcessingTime);
    }

    /*********************************************************************************
     *                                                                               *
     *                            VIEW-ONLY FUNCTIONS                                *
     *                                                                               *
     *********************************************************************************/

    /**
     * @dev In the future with ICA, this function could call ICA contract to retrieve
     *      total tokens staked across validators.
     */
    function getTotalPooledToken() public view returns (uint256) {
        return totalPooledToken;
    }

    function convertToShare(uint256 tokenAmount) public view override returns (uint256) {
        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) return tokenAmount;

        uint256 share = (tokenAmount * totalSupply) / totalPooledToken;
        // Protect user in the case where user deposit in small amount resulting in 0 share
        require(share > 0, "Invalid share");

        return share;
    }

    function convertToAsset(uint256 shareAmount) public view override returns (uint256) {
        uint256 totalSupply = totalSupply();

        // if totalSupply == 0, it means either (1) protocol just launched or (2) protocol got slashed until 0
        // in either case, returning 0 is expected as liquid token will swap to 0 token
        if (totalSupply == 0) return 0;
        return (shareAmount * totalPooledToken) / totalSupply;
    }

    function convertToAssetWithUnbondingFee(
        uint256 shareAmount
    ) public view override returns (uint256 tokenAmt, uint256 unbondingFeeAmt) {
        uint256 totalTokenAmount = convertToAsset(shareAmount);

        unbondingFeeAmt = (totalTokenAmount * unbondingFee) / UNBONDING_FEE_DENOMINATOR;
        tokenAmt = totalTokenAmount - unbondingFeeAmt;
    }

    function getUnbondRequestLength() external view returns (uint256) {
        return unbondRequests.length();
    }

    function getUnbondRequests(uint256 limit, uint256 offset) external view returns (uint256[] memory) {
        uint256[] memory elements = new uint256[](limit);

        for (uint256 i = 0; i < elements.length; i++) {
            elements[i] = unbondRequests.at(i + offset);
        }

        return elements;
    }

    /**
     * @notice This is an estimation unlock date as there can be unforseen circumstance such as
     *         IBC relayer delay or bot issue. When ICA is live, this unlock date would be accurate
     * @return unboundUnlockDate if the user unbond now
     */
    function getUnbondUnlockDate() public view returns (uint256) {
        // Check if previous batch is in PROCESSING status. If processing, assume unbonding will be successful
        // soon and thus return unlockTime as block.timestamp + unbondingProcessingTime + unbondingDuration;
        // Note: If this is not in place, it means that protocol will promise an earlier unlock date than possible
        //       during this window of processing -> unbonding (1 hour)
        if (currentUnbondingBatchNo > 0) {
            if (batch2UnbondingStatus[currentUnbondingBatchNo - 1] == UnbondingStatus.PROCESSING) {
                return block.timestamp + unbondingProcessingTime + unbondingDuration;
            }
        }

        uint256 nextUnbondTime = lastUnbondTime + unbondingProcessingTime;
        if (nextUnbondTime < block.timestamp) {
            // This happen when contract just deployed (lastUnbondTime = 0) or when the bot has not unbonded
            // since 4 days 12 hours ago (unbondingProcessingTime), could be bot issue.
            // If this is not in place, it means that the protocol will promise an earlier unlock date than possible
            return block.timestamp + unbondingProcessingTime + unbondingDuration;
        }

        return nextUnbondTime + unbondingDuration;
    }

    /*********************************************************************************
     *                                                                               *
     *                            INTERNAL FUNCTIONS                                 *
     *                                                                               *
     *********************************************************************************/

    /**
     * @dev Required by UUPSUpgradeableWithDelay
     */
    function _authorizeUpgradeWithDelay(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
