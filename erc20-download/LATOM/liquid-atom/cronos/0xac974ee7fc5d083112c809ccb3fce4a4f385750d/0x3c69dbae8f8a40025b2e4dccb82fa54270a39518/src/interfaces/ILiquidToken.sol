// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "../LiquidTokenStorage.sol";

/**
 * @notice interface for both CRC20 and CRC21 LiquidToken implementation
 */
interface ILiquidToken {
    /**
     * @notice Process user's token deposit and mint LiquidToken to receiver
     * @return minted shares from user's deposit
     */
    function stake(address receiver, uint256 amount) external returns (uint256);

    /**
     * @notice Process user's unbonding request - conversion of LiquidToken to
     *         staked token. Also mint an ERC-721 NFT to represent the request
     * @param shareAmount Total share amount to unbound
     * @param receiver To receive the ERC-721 NFT
     * @return tokenId ERC721 tokenId
     */
    function requestUnbond(uint256 shareAmount, address receiver) external returns (uint256);

    /**
     * @notice Batch unbond, swapping list of tokenIds for token amount
     * @param _tokenIds array of ERC-721 received when receiver requestUnbond
     * @return tokenAmount Represent total token amount user receives for the batch
     */
    function batchUnbond(uint256[] calldata _tokenIds, address _receiver) external returns (uint256);

    /**
     * @notice After cooldown period, return user's token
     * @param tokenId of ERC-721 received when receiver requestUnbond
     * @return tokenAmount Represent total token user receives
     */
    function unbond(uint256 tokenId, address receiver) external returns (uint256);

    /*********************************************************************************
     *                                                                               *
     *                            BOT-RELATED FUNCTIONS                               *
     *                                                                               *
     *********************************************************************************/

    /**
     * @notice Bridge token to a cosmos chain (chain depends on which protocol eg. ATOM/OSMOS etc..)
     */
    function bridge(uint256 amount) external;

    /**
     * @notice Accrue staking reward to the pool
     * @param amount of token reward from GetReward call the cosmos chain
     * @param txnHash Hash of GetReward call
     */
    function accrueReward(uint256 amount, string calldata txnHash) external;

    /**
     * @notice Initiated by protocol only when validator receive slashing, protocol take loss as a whole
     * @param validatorAddress Slashed validator
     * @param amount of token slashed
     * @param time When the slash happened on Crypto.org
     */
    function slash(string calldata validatorAddress, uint256 amount, uint256 time) external;

    /**
     * @notice Initiated by protocol only when validator receive slashing, protocol take loss as a whole
     * @param _tokenIds list of unbonding requests to slash
     * @param _exchangeRates updated exchange rate for each request
     */
    function slashUnbondingRequests(uint256[] calldata _tokenIds, uint256[] calldata _exchangeRates) external;

    /**
     * @notice Update the batch processing status
     * @param _batchNo to update
     * @param _status to be update for the batch
     */
    function setUnbondingBatchStatus(uint256 _batchNo, LiquidTokenStorage.UnbondingStatus _status) external;

    /*********************************************************************************
     *                                                                               *
     *                            VIEW FUNCTIONS                                     *
     *                                                                               *
     *********************************************************************************/

    /**
     * @return The amount of share that correspond to this tokenAmount
     */
    function convertToShare(uint256 tokenAmount) external view returns (uint256);

    /**
     * @return The amount of CRO that corresponds to this shareAmount
     */
    function convertToAsset(uint256 shareAmount) external view returns (uint256);

    /**
     * @notice helper function for FE to get the fee and token amount
     * @return tokenAmt Amount of token user will receive after deducting unbondingFee
     * @return unbondingFeeAmt Amount of token amount taken as unbondingFee
     */
    function convertToAssetWithUnbondingFee(
        uint256 shareAmount
    ) external view returns (uint256 tokenAmt, uint256 unbondingFeeAmt);

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
