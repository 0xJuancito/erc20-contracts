// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./UUPSUpgradeableWithDelay.sol";
import "./interfaces/ILiquidCro.sol";
import "./LiquidCroStorage.sol";

contract LiquidCro is
    ILiquidCro,
    ERC20Upgradeable,
    UUPSUpgradeableWithDelay,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    LiquidCroStorage
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    /// @notice Emitted when user stake CRO
    event Stake(address indexed receiver, uint256 croAmount, uint256 shareAmount);

    /// @notice Emitted when a user request to unbond their staked cro
    event RequestUnbond(
        address indexed receiver,
        uint256 indexed tokenId,
        uint256 shareAmount,
        uint256 liquidCro2CroExchangeRate,
        uint256 batchNo
    );

    /// @notice Emitted when a user redeems the NFT for CRO
    event Unbond(address indexed receiver, uint256 indexed tokenId, uint256 croAmount, uint256 croFeeAmount);

    /// @notice Emitted when the bot has an update for an unbonding batch
    event SetUnbondingBatchStatus(uint256 batchNo, UnbondingStatus status);

    /// @notice Emitted when the bot claim reward on Crypto.org
    event AccrueReward(uint256 indexed amount, string indexed txnHash);

    /// @notice Emitted when a slash happen on unbonding request
    event SlashRequest(uint256 tokenId, uint256 oldExchangeRate, uint256 newExchangeRate);

    /// @notice Emitted when a slash happen on Crypto.org
    event Slash(string indexed validatorAddress, uint256 indexed amount, uint256 time);

    /// @notice Emitted when a new bridge destination on Crypto.org is set
    event SetBridgeDestination(string oldDestination, string newDestination);

    /// @notice Emitted when the CRO is bridged over to Crypto.org
    event Bridge(uint256 amount);

    /// @notice Emitted when CRO is bridged from Crypto.org back to contract
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
     * @param _croBridge Bridge CRO to Crypto.org chain
     * @param _ibcReceiver IBC fund from crypto.org are IBC to here
     * @param _treasury Withdrawal fee will be sent here
     * @param _upgradeDelay Time to wait before new upgrade implementation
     */
    function initialize(
        IVenoNft _venoNft,
        ICroBridge _croBridge,
        IIBCReceiver _ibcReceiver,
        address _treasury,
        uint256 _upgradeDelay
    ) public initializer {
        require(address(_venoNft) != address(0), "venoNft addresss zero");
        require(address(_croBridge) != address(0), "croBridge address zero");
        require(address(_ibcReceiver) != address(0), "ibcReceiver address zero");
        require(_treasury != address(0), "treasury address zero");
        require(_upgradeDelay > 0, "upgradeDelay is zero");

        venoNft = _venoNft;
        croBridge = _croBridge;
        ibcReceiver = _ibcReceiver;
        treasury = _treasury;

        // Default 0.2%
        unbondingFee = 200;
        unbondingDuration = 28 days;

        // 4 days from max 7 concurrent unbonding request and 12 hours for:
        // 1) bot to process unbonding
        // 2) bot to IBC the cro back after unbonding
        // When the protocol is stable, the 12 hours can be reduced gradually
        unbondingProcessingTime = 4 days + 12 hours;

        // Set batch 0 as pending status
        batch2UnbondingStatus[currentUnbondingBatchNo] = UnbondingStatus.PENDING_BOT;

        __ERC20_init("Liquid CRO", "LCRO");
        __UUPSUpgradeableWithDelay_init(_upgradeDelay);
        __Pausable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function stake(address _receiver) external payable override nonReentrant whenNotPaused returns (uint256) {
        require(_receiver != address(0), "ZERO_ADDRESS");
        require(msg.value > 0, "ZERO_DEPOSIT");
        require(msg.value % 1e10 == 0, "MAX_8_DECIMALS");

        uint256 shareAmount = convertToShare(msg.value);
        _mint(_receiver, shareAmount);

        totalPooledCro += msg.value;
        totalCroToBridge += msg.value;

        emit Stake(_receiver, msg.value, shareAmount);
        return shareAmount;
    }

    function requestUnbond(
        uint256 _shareAmount,
        address _receiver
    ) external override nonReentrant whenNotPaused returns (uint256) {
        require(_receiver != address(0), "ZERO_ADDRESS");
        require(_shareAmount > 0, "ZERO_SHAREAMOUNT");

        uint256 unlockTime = getUnbondUnlockDate();
        uint256 tokenId = venoNft.mint(_receiver);
        unbondRequests.add(tokenId);

        uint256 liquidCro2CroExchangeRate = (totalPooledCro * EXCHANGE_RATE_PRECISION) / totalSupply();
        token2UnbondRequest[tokenId] = UnbondRequest({
            unlockStartTime: uint128(block.timestamp),
            unlockEndTime: uint128(unlockTime),
            liquidCroAmount: _shareAmount,
            liquidCro2CroExchangeRate: liquidCro2CroExchangeRate,
            batchNo: currentUnbondingBatchNo
        });

        // Reduce totalPooledCro in protocol and burn share
        totalPooledCro -= (_shareAmount * liquidCro2CroExchangeRate) / EXCHANGE_RATE_PRECISION;
        _burn(msg.sender, _shareAmount);

        emit RequestUnbond(
            _receiver,
            tokenId,
            _shareAmount,
            liquidCro2CroExchangeRate,
            currentUnbondingBatchNo
        );
        return tokenId;
    }

    function batchUnbond(
        uint256[] calldata _tokenIds,
        address _receiver
    ) external override returns (uint256) {
        uint256 totalCroAmt;
        for (uint256 i; i < _tokenIds.length; i++) {
            totalCroAmt += unbond(_tokenIds[i], _receiver);
        }

        return totalCroAmt;
    }

    function unbond(
        uint256 _tokenId,
        address _receiver
    ) public override nonReentrant whenNotPaused returns (uint256) {
        require(_receiver != address(0), "ZERO_ADDRESS");
        require(venoNft.isApprovedOrOwner(msg.sender, _tokenId), "NOT_OWNER");

        UnbondRequest storage unbondRequest = token2UnbondRequest[_tokenId];
        require(unbondRequest.unlockEndTime <= block.timestamp, "NOT_UNLOCK_YET");

        UnbondingStatus status = batch2UnbondingStatus[unbondRequest.batchNo];
        require(status == UnbondingStatus.UNBONDED, "NOT_UNBONDED_YET");

        // Collect any pending CRO - this would prevent a situation where fund are in IBCReceiver
        // and the bot have not take the fund over
        if (address(ibcReceiver).balance > 0) {
            ibcReceiver.transfer();
        }

        // Burn NFT
        venoNft.burn(_tokenId);
        unbondRequests.remove(_tokenId);

        uint256 totalCroAmount = (unbondRequest.liquidCroAmount * unbondRequest.liquidCro2CroExchangeRate) /
            EXCHANGE_RATE_PRECISION;

        // Send cro fee amount to treasury
        uint256 croFeeAmount = (totalCroAmount * unbondingFee) / UNBONDING_FEE_DENOMINATOR;
        payable(treasury).transfer(croFeeAmount);

        // Send cro amount to user
        uint256 croAmount = totalCroAmount - croFeeAmount;
        payable(_receiver).transfer(croAmount);

        emit Unbond(_receiver, _tokenId, croAmount, croFeeAmount);
        return croAmount;
    }

    /// @dev deposit CRO into the contract, meant mostly for IBCReceiver to call
    function deposit() external payable override {
        emit Deposit(msg.value);
    }

    /*********************************************************************************
     *                                                                               *
     *                    BOT AND ADMIN-ONLY FUNCTIONS                               *
     *                                                                               *
     *********************************************************************************/

    function accrueReward(uint256 amount, string calldata txnHash) external override onlyRole(ROLE_BOT) {
        require(amount > 0, "ZERO_AMOUNT");
        require(txnHash2AccrueRewardAmount[txnHash] == 0, "ACCRUE_RECORDED");

        totalPooledCro += amount;
        txnHash2AccrueRewardAmount[txnHash] = amount;

        emit AccrueReward(amount, txnHash);
    }

    function bridge(uint256 amount) external override onlyRole(ROLE_BOT) {
        require(amount <= totalCroToBridge, "amount must be smaller than totalCroToBridge");

        require(bytes(bridgeDestination).length > 0, "EMPTY_DESTINATION");

        totalCroToBridge -= amount;
        croBridge.send_cro_to_crypto_org{value: amount}(bridgeDestination);

        emit Bridge(amount);
    }

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
            require(request.liquidCro2CroExchangeRate > _newRates[i], "New exchange rate must be lower");
            require(
                (request.liquidCro2CroExchangeRate * 9) / 10 <= _newRates[i],
                "New exchange rate cannot drop more than 10 percent"
            );

            uint256 oldRate = request.liquidCro2CroExchangeRate;
            request.liquidCro2CroExchangeRate = _newRates[i];

            emit SlashRequest(_tokenIds[i], oldRate, _newRates[i]);
        }
    }

    /**
     * @dev see interface on detailed instruction, only execute this after calculating how much
     *      cro to slash between unbonding users / protocol (both parties should slash by equal percentage)
     */
    function slash(
        string calldata _validatorAddress,
        uint256 _amount,
        uint256 _time
    ) external override onlyRole(ROLE_SLASHER) {
        require(validator2Time2AmountSlashed[_validatorAddress][_time] == 0, "SLASH_RECORDED");
        require(_amount > 0, "ZERO_AMOUNT");
        // totalPooledCro cannot go to 0, otherwise convertToShare will not mint the correct share for new stakers
        require(_amount < totalPooledCro, "amount must be less than totalPooledCro");

        validator2Time2AmountSlashed[_validatorAddress][_time] = _amount;
        totalPooledCro -= _amount;

        emit Slash(_validatorAddress, _amount, _time);
    }

    function setBridgeDestination(string memory _destination) external onlyRole(DEFAULT_ADMIN_ROLE) {
        //TODO: potentially better validation on destination
        require(bytes(_destination).length > 0, "EMPTY_DESTINATION");

        string memory oldDestination = bridgeDestination;
        bridgeDestination = _destination;
        emit SetBridgeDestination(oldDestination, _destination);
    }

    /// @param _unbondingFee - 100 = 0.1%
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
     * @dev only called if Crypto org has a new proposal which changes the unbonding duration
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
     *      totalCRO staked across validators.
     */
    function getTotalPooledCro() public view returns (uint256) {
        return totalPooledCro;
    }

    function convertToShare(uint256 croAmount) public view override returns (uint256) {
        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) return croAmount;

        uint256 share = (croAmount * totalSupply) / totalPooledCro;
        // Protect user in the case where user deposit in small amount resulting in 0 share
        require(share > 0, "Invalid share");

        return share;
    }

    function convertToAsset(uint256 shareAmount) public view override returns (uint256) {
        uint256 totalSupply = totalSupply();

        // if totalSupply == 0, it means either (1) protocol just launched or (2) protocol got slashed until 0
        // in either case, returning 0 is expected as LCRO will swap to 0 CRO
        if (totalSupply == 0) return 0;
        return (shareAmount * totalPooledCro) / totalSupply;
    }

    function convertToAssetWithUnbondingFee(
        uint256 shareAmount
    ) public view override returns (uint256 croAmt, uint256 unbondingFeeAmt) {
        uint256 totalCroAmount = convertToAsset(shareAmount);

        unbondingFeeAmt = (totalCroAmount * unbondingFee) / UNBONDING_FEE_DENOMINATOR;
        croAmt = totalCroAmount - unbondingFeeAmt;
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
