// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "../LiquidCroStorage.sol";

interface ILiquidCro {
    /**
     * @notice Process user's cro deposit and mint LiquidCro to receiver
     * @return minted shares from user's deposit
     */
    function stake(address receiver) external payable returns (uint256);

    /**
     * @notice Process user's unbonding request - conversion of LiquidCro to
     *         staked CRO. Also mint an ERC-721 NFT to represent the request
     * @param shareAmount Total share amount to unbound
     * @param receiver To receive the ERC-721 NFT
     * @return tokenId ERC721 tokenId
     */
    function requestUnbond(uint256 shareAmount, address receiver) external returns (uint256);

    /**
     * @notice Batch unbond, swapping list of tokenIds for CRO amount
     * @param _tokenIds array of ERC-721 received when receiver requestUnbond
     * @return croAmount Represent total CRO user receives for the batch
     */
    function batchUnbond(uint256[] calldata _tokenIds, address _receiver) external returns (uint256);

    /**
     * @notice After cooldown period, return user's CRO
     * @param tokenId of ERC-721 received when receiver requestUnbond
     * @return croAmount Represent total CRO user receives
     */
    function unbond(uint256 tokenId, address receiver) external returns (uint256);

    /*********************************************************************************
     *                                                                               *
     *                            BOT-RELATED FUNCTIONS                               *
     *                                                                               *
     *********************************************************************************/

    /**
     * @notice Bridge CRO to Crypto.org chain
     */
    function bridge(uint256 amount) external;

    /**
     * @notice Accrue staking reward to the pool
     * @param amount of cro reward from GetReward call at Crypto.org
     * @param txnHash Hash of GetReward call
     */
    function accrueReward(uint256 amount, string calldata txnHash) external;

    /**
     * @notice Initiated by protocol only when validator receive slashing, protocol take loss as a whole
     * @param validatorAddress Slashed validator
     * @param amount of cro slashed
     * @param time When the slash happened on Crypto.org
     */
    function slash(
        string calldata validatorAddress,
        uint256 amount,
        uint256 time
    ) external;

    /**
     * @notice Initiated by protocol only when validator receive slashing, protocol take loss as a whole
     * @param _tokenIds list of unbonding requests to slash
     * @param _exchangeRates updated exchange rate for each request
     */
    function slashUnbondingRequests(uint256[] calldata _tokenIds, uint256[] calldata _exchangeRates) external;

    /**
     * @notice Deposit CRO into the contract without minting share
     * @dev Called by IBCReceiver to deposit bridged CRO from Crypto org
     */
    function deposit() external payable;

    /**
     * @notice Update the batch processing status
     * @param _batchNo to update
     * @param _status to be update for the batch
     */
    function setUnbondingBatchStatus(uint256 _batchNo, LiquidCroStorage.UnbondingStatus _status) external;

    /*********************************************************************************
     *                                                                               *
     *                            VIEW FUNCTIONS                                     *
     *                                                                               *
     *********************************************************************************/

    /**
     * @return The amount of share that correspond to this croAmount
     */
    function convertToShare(uint256 croAmount) external view returns (uint256);

    /**
     * @return The amount of CRO that corresponds to this shareAmount
     */
    function convertToAsset(uint256 shareAmount) external view returns (uint256);

    /**
     * @notice helper function for FE to get the fee and cro amount
     * @return croAmt Amount of cro user will receive after deducting unbondingFee
     * @return unbondingFeeAmt Amount of cro amount taken as unbondingFee
     */
    function convertToAssetWithUnbondingFee(uint256 shareAmount)
        external
        view
        returns (uint256 croAmt, uint256 unbondingFeeAmt);

    /**
     * @return length of unclaimed unbonding requests
     */
    function getUnbondRequestLength() external view returns (uint256);

    /**
     * @param limit number of results to return
     * @param offset starting index of result
     * @return list of tokensId
     */
    function getUnbondRequests(uint256 limit, uint256 offset) external view returns (uint256[] memory);

    /**
     * @notice returns the next unlock date for new unbonding request
     * @return timestamp in sec on next unlock date
     */
    function getUnbondUnlockDate() external view returns (uint256);
}
