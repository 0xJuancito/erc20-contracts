// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../libs/calcFunctions.sol";

//custom errors
error TitanX_InvalidStakeLength();
error TitanX_RequireOneMinimumShare();
error TitanX_ExceedMaxAmountPerStake();
error TitanX_NoStakeExists();
error TitanX_StakeHasEnded();
error TitanX_StakeNotMatured();
error TitanX_StakeHasBurned();
error TitanX_MaxedWalletStakes();

abstract contract StakeInfo {
    //Variables
    /** @dev track global stake Id */
    uint256 private s_globalStakeId;
    /** @dev track global shares */
    uint256 private s_globalShares;
    /** @dev track global expired shares */
    uint256 private s_globalExpiredShares;
    /** @dev track global staked titan */
    uint256 private s_globalTitanStaked;
    /** @dev track global end stake penalty */
    uint256 private s_globalStakePenalty;
    /** @dev track global ended stake */
    uint256 private s_globalStakeEnd;
    /** @dev track global burned stake */
    uint256 private s_globalStakeBurn;

    //mappings
    /** @dev track address => stakeId */
    mapping(address => uint256) private s_addressSId;
    /** @dev track address, stakeId => global stake Id */
    mapping(address => mapping(uint256 => uint256)) private s_addressSIdToGlobalStakeId;
    /** @dev track global stake Id => stake info */
    mapping(uint256 => UserStakeInfo) private s_globalStakeIdToStakeInfo;

    /** @dev track address => shares Index */
    mapping(address => uint256) private s_userSharesIndex;
    /** @dev track user total active shares by user shares index
     * s_addressIdToActiveShares[user][index] = UserActiveShares (contract day, total user active shares)
     * works like a snapshot or log when user shares has changed (increase/decrease)
     */
    mapping(address => mapping(uint256 => UserActiveShares)) private s_addressIdToActiveShares;

    //structs
    struct UserStakeInfo {
        uint152 titanAmount;
        uint128 shares;
        uint16 numOfDays;
        uint48 stakeStartTs;
        uint48 maturityTs;
        StakeStatus status;
    }

    struct UserStake {
        uint256 sId;
        uint256 globalStakeId;
        UserStakeInfo stakeInfo;
    }

    struct UserActiveShares {
        uint256 day;
        uint256 activeShares;
    }

    //events
    event StakeStarted(
        address indexed user,
        uint256 indexed globalStakeId,
        uint256 numOfDays,
        UserStakeInfo indexed userStakeInfo
    );

    event StakeEnded(
        address indexed user,
        uint256 indexed globalStakeId,
        uint256 titanAmount,
        uint256 indexed penalty,
        uint256 penaltyAmount
    );

    //functions
    /** @dev create a new stake
     * @param user user address
     * @param amount titan amount
     * @param numOfDays stake lenght
     * @param shareRate current share rate
     * @param day current contract day
     * @param isPayoutTriggered has global payout triggered
     * @return isFirstShares first created shares or not
     */
    function _startStake(
        address user,
        uint256 amount,
        uint256 numOfDays,
        uint256 shareRate,
        uint256 day,
        PayoutTriggered isPayoutTriggered
    ) internal returns (uint256 isFirstShares) {
        uint256 sId = ++s_addressSId[user];
        if (sId > MAX_STAKE_PER_WALLET) revert TitanX_MaxedWalletStakes();
        if (numOfDays < MIN_STAKE_LENGTH || numOfDays > MAX_STAKE_LENGTH)
            revert TitanX_InvalidStakeLength();

        //calculate shares
        uint256 shares = calculateShares(amount, numOfDays, shareRate);
        if (shares / SCALING_FACTOR_1e18 < 1) revert TitanX_RequireOneMinimumShare();

        uint256 currentGStakeId = ++s_globalStakeId;
        uint256 maturityTs;

        maturityTs = block.timestamp + (numOfDays * SECONDS_IN_DAY);

        UserStakeInfo memory userStakeInfo = UserStakeInfo({
            titanAmount: uint152(amount),
            shares: uint128(shares),
            numOfDays: uint16(numOfDays),
            stakeStartTs: uint48(block.timestamp),
            maturityTs: uint48(maturityTs),
            status: StakeStatus.ACTIVE
        });

        /** s_addressSId[user] tracks stake Id for each address
         * s_addressSIdToGlobalStakeId[user][id] tracks stack id to global stake Id
         * s_globalStakeIdToStakeInfo[currentGStakeId] stores stake info
         */
        s_addressSIdToGlobalStakeId[user][sId] = currentGStakeId;
        s_globalStakeIdToStakeInfo[currentGStakeId] = userStakeInfo;

        //update shares changes
        isFirstShares = _updateSharesStats(
            user,
            shares,
            amount,
            day,
            isPayoutTriggered,
            StakeAction.START
        );

        emit StakeStarted(user, currentGStakeId, numOfDays, userStakeInfo);
    }

    /** @dev end stake and calculate pinciple with penalties (if any) or burn stake
     * @param user user address
     * @param id stake Id
     * @param day current contract day
     * @param action end stake or burn stake
     * @param payOther is end stake for others
     * @param isPayoutTriggered has global payout triggered
     * @return titan titan principle
     */
    function _endStake(
        address user,
        uint256 id,
        uint256 day,
        StakeAction action,
        StakeAction payOther,
        PayoutTriggered isPayoutTriggered
    ) internal returns (uint256 titan) {
        uint256 globalStakeId = s_addressSIdToGlobalStakeId[user][id];
        if (globalStakeId == 0) revert TitanX_NoStakeExists();

        UserStakeInfo memory userStakeInfo = s_globalStakeIdToStakeInfo[globalStakeId];
        if (userStakeInfo.status == StakeStatus.ENDED) revert TitanX_StakeHasEnded();
        if (userStakeInfo.status == StakeStatus.BURNED) revert TitanX_StakeHasBurned();
        //end stake for others requires matured stake to prevent EES for others
        if (payOther == StakeAction.END_OTHER && block.timestamp < userStakeInfo.maturityTs)
            revert TitanX_StakeNotMatured();

        //update shares changes
        uint256 shares = userStakeInfo.shares;
        _updateSharesStats(user, shares, userStakeInfo.titanAmount, day, isPayoutTriggered, action);

        if (action == StakeAction.END) {
            ++s_globalStakeEnd;
            s_globalStakeIdToStakeInfo[globalStakeId].status = StakeStatus.ENDED;
        } else if (action == StakeAction.BURN) {
            ++s_globalStakeBurn;
            s_globalStakeIdToStakeInfo[globalStakeId].status = StakeStatus.BURNED;
        }

        titan = _calculatePrinciple(user, globalStakeId, userStakeInfo, action);
    }

    /** @dev update shares changes to track when user shares has changed, this affect the payout calculation
     * @param user user address
     * @param shares shares
     * @param amount titan amount
     * @param day current contract day
     * @param isPayoutTriggered has global payout triggered
     * @param action start stake or end stake
     * @return isFirstShares first created shares or not
     */
    function _updateSharesStats(
        address user,
        uint256 shares,
        uint256 amount,
        uint256 day,
        PayoutTriggered isPayoutTriggered,
        StakeAction action
    ) private returns (uint256 isFirstShares) {
        //Get previous active shares to calculate new shares change
        uint256 index = s_userSharesIndex[user];
        uint256 previousShares = s_addressIdToActiveShares[user][index].activeShares;

        if (action == StakeAction.START) {
            //return 1 if this is a new wallet address
            //this is used to initialize last claim index to the latest cycle index
            if (index == 0) isFirstShares = 1;

            s_addressIdToActiveShares[user][++index].activeShares = previousShares + shares;
            s_globalShares += shares;
            s_globalTitanStaked += amount;
        } else {
            s_addressIdToActiveShares[user][++index].activeShares = previousShares - shares;
            s_globalExpiredShares += shares;
            s_globalTitanStaked -= amount;
        }

        //If global payout hasn't triggered, use current contract day to eligible for payout
        //If global payout has triggered, then start with next contract day as it's no longer eligible to claim latest payout
        s_addressIdToActiveShares[user][index].day = uint128(
            isPayoutTriggered == PayoutTriggered.NO ? day : day + 1
        );

        s_userSharesIndex[user] = index;
    }

    /** @dev calculate stake principle and apply penalty (if any)
     * @param user user address
     * @param globalStakeId global stake Id
     * @param userStakeInfo stake info
     * @param action end stake or burn stake
     * @return principle calculated principle after penalty (if any)
     */
    function _calculatePrinciple(
        address user,
        uint256 globalStakeId,
        UserStakeInfo memory userStakeInfo,
        StakeAction action
    ) internal returns (uint256 principle) {
        uint256 titanAmount = userStakeInfo.titanAmount;
        //penalty is in percentage
        uint256 penalty = calculateEndStakePenalty(
            userStakeInfo.stakeStartTs,
            userStakeInfo.maturityTs,
            block.timestamp,
            action
        );

        uint256 penaltyAmount;
        penaltyAmount = (titanAmount * penalty) / 100;
        principle = titanAmount - penaltyAmount;
        s_globalStakePenalty += penaltyAmount;

        emit StakeEnded(user, globalStakeId, principle, penalty, penaltyAmount);
    }

    //Views
    /** @notice get global shares
     * @return globalShares global shares
     */
    function getGlobalShares() public view returns (uint256) {
        return s_globalShares;
    }

    /** @notice get global expired shares
     * @return globalExpiredShares global expired shares
     */
    function getGlobalExpiredShares() public view returns (uint256) {
        return s_globalExpiredShares;
    }

    /** @notice get global active shares
     * @return globalActiveShares global active shares
     */
    function getGlobalActiveShares() public view returns (uint256) {
        return s_globalShares - s_globalExpiredShares;
    }

    /** @notice get total titan staked
     * @return totalTitanStaked total titan staked
     */
    function getTotalTitanStaked() public view returns (uint256) {
        return s_globalTitanStaked;
    }

    /** @notice get global stake id
     * @return globalStakeId global stake id
     */
    function getGlobalStakeId() public view returns (uint256) {
        return s_globalStakeId;
    }

    /** @notice get global active stakes
     * @return globalActiveStakes global active stakes
     */
    function getGlobalActiveStakes() public view returns (uint256) {
        return s_globalStakeId - getTotalStakeEnd();
    }

    /** @notice get total stake ended
     * @return totalStakeEnded total stake ended
     */
    function getTotalStakeEnd() public view returns (uint256) {
        return s_globalStakeEnd;
    }

    /** @notice get total stake burned
     * @return totalStakeBurned total stake burned
     */
    function getTotalStakeBurn() public view returns (uint256) {
        return s_globalStakeBurn;
    }

    /** @notice get total end stake penalty
     * @return totalEndStakePenalty total end stake penalty
     */
    function getTotalStakePenalty() public view returns (uint256) {
        return s_globalStakePenalty;
    }

    /** @notice get user latest shares index
     * @return latestSharesIndex latest shares index
     */
    function getUserLatestShareIndex(address user) public view returns (uint256) {
        return s_userSharesIndex[user];
    }

    /** @notice get user current active shares
     * @return currentActiveShares current active shares
     */
    function getUserCurrentActiveShares(address user) public view returns (uint256) {
        return s_addressIdToActiveShares[user][getUserLatestShareIndex(user)].activeShares;
    }

    /** @notice get user active shares at sharesIndex
     * @return activeShares active shares at sharesIndex
     */
    function getUserActiveShares(
        address user,
        uint256 sharesIndex
    ) internal view returns (uint256) {
        return s_addressIdToActiveShares[user][sharesIndex].activeShares;
    }

    /** @notice get user active shares contract day at sharesIndex
     * @return activeSharesDay active shares contract day at sharesIndex
     */
    function getUserActiveSharesDay(
        address user,
        uint256 sharesIndex
    ) internal view returns (uint256) {
        return s_addressIdToActiveShares[user][sharesIndex].day;
    }

    /** @notice get stake info with stake id
     * @return stakeInfo stake info
     */
    function getUserStakeInfo(address user, uint256 id) public view returns (UserStakeInfo memory) {
        return s_globalStakeIdToStakeInfo[s_addressSIdToGlobalStakeId[user][id]];
    }

    /** @notice get all stake info of an address
     * @return stakeInfos all stake info of an address
     */
    function getUserStakes(address user) public view returns (UserStake[] memory) {
        uint256 count = s_addressSId[user];
        UserStake[] memory stakes = new UserStake[](count);

        for (uint256 i = 1; i <= count; i++) {
            stakes[i - 1] = UserStake({
                sId: i,
                globalStakeId: uint128(s_addressSIdToGlobalStakeId[user][i]),
                stakeInfo: getUserStakeInfo(user, i)
            });
        }

        return stakes;
    }
}
