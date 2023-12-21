// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../libs/calcFunctions.sol";

//custom errors
error TitanX_InvalidMintLength();
error TitanX_InvalidMintPower();
error TitanX_NoMintExists();
error TitanX_MintHasClaimed();
error TitanX_MintNotMature();
error TitanX_MintHasBurned();

abstract contract MintInfo {
    //variables
    /** @dev track global tRank */
    uint256 private s_globalTRank;
    /** @dev track total mint claimed */
    uint256 private s_globalMintClaim;
    /** @dev track total mint burned */
    uint256 private s_globalMintBurn;
    /** @dev track total titan minting */
    uint256 private s_globalTitanMinting;
    /** @dev track total titan penalty */
    uint256 private s_globalTitanMintPenalty;
    /** @dev track global mint power */
    uint256 private s_globalMintPower;

    //mappings
    /** @dev track address => mintId */
    mapping(address => uint256) private s_addressMId;
    /** @dev track address, mintId => tRank info (gTrank, gMintPower) */
    mapping(address => mapping(uint256 => TRankInfo)) private s_addressMIdToTRankInfo;
    /** @dev track global tRank => mintInfo*/
    mapping(uint256 => UserMintInfo) private s_tRankToMintInfo;

    //structs
    struct UserMintInfo {
        uint8 mintPower;
        uint16 numOfDays;
        uint96 mintableTitan;
        uint48 mintStartTs;
        uint48 maturityTs;
        uint32 mintPowerBonus;
        uint32 EAABonus;
        uint128 mintedTitan;
        uint64 mintCost;
        MintStatus status;
    }

    struct TRankInfo {
        uint256 tRank;
        uint256 gMintPower;
    }

    struct UserMint {
        uint256 mId;
        uint256 tRank;
        uint256 gMintPower;
        UserMintInfo mintInfo;
    }

    //events
    event MintStarted(
        address indexed user,
        uint256 indexed tRank,
        uint256 indexed gMintpower,
        UserMintInfo userMintInfo
    );

    event MintClaimed(
        address indexed user,
        uint256 indexed tRank,
        uint256 rewardMinted,
        uint256 indexed penalty,
        uint256 mintPenalty
    );

    //functions
    /** @dev create a new mint
     * @param user user address
     * @param mintPower mint power
     * @param numOfDays mint lenght
     * @param mintableTitan mintable titan
     * @param mintPowerBonus mint power bonus
     * @param EAABonus EAA bonus
     * @param burnAmpBonus burn amplifier bonus
     * @param gMintPower global mint power
     * @param currentTRank current global tRank
     * @param mintCost actual mint cost paid for a mint
     */
    function _startMint(
        address user,
        uint256 mintPower,
        uint256 numOfDays,
        uint256 mintableTitan,
        uint256 mintPowerBonus,
        uint256 EAABonus,
        uint256 burnAmpBonus,
        uint256 gMintPower,
        uint256 currentTRank,
        uint256 mintCost
    ) internal returns (uint256 mintable) {
        if (numOfDays == 0 || numOfDays > MAX_MINT_LENGTH) revert TitanX_InvalidMintLength();
        if (mintPower == 0 || mintPower > MAX_MINT_POWER_CAP) revert TitanX_InvalidMintPower();

        //calculate mint reward up front with the provided params
        mintable = calculateMintReward(mintPower, numOfDays, mintableTitan, EAABonus, burnAmpBonus);

        //store variables into mint info
        UserMintInfo memory userMintInfo = UserMintInfo({
            mintPower: uint8(mintPower),
            numOfDays: uint16(numOfDays),
            mintableTitan: uint96(mintable),
            mintPowerBonus: uint32(mintPowerBonus),
            EAABonus: uint32(EAABonus),
            mintStartTs: uint48(block.timestamp),
            maturityTs: uint48(block.timestamp + (numOfDays * SECONDS_IN_DAY)),
            mintedTitan: 0,
            mintCost: uint64(mintCost),
            status: MintStatus.ACTIVE
        });

        /** s_addressMId[user] tracks mintId for each addrress
         * s_addressMIdToTRankInfo[user][id] tracks current mint tRank and gPowerMint
         *  s_tRankToMintInfo[currentTRank] stores mint info
         */
        uint256 id = ++s_addressMId[user];
        s_addressMIdToTRankInfo[user][id].tRank = currentTRank;
        s_addressMIdToTRankInfo[user][id].gMintPower = gMintPower;
        s_tRankToMintInfo[currentTRank] = userMintInfo;

        emit MintStarted(user, currentTRank, gMintPower, userMintInfo);
    }

    /** @dev create new mint in a batch of up to max 100 mints with the same mint length
     * @param user user address
     * @param mintPower mint power
     * @param numOfDays mint lenght
     * @param mintableTitan mintable titan
     * @param mintPowerBonus mint power bonus
     * @param EAABonus EAA bonus
     * @param burnAmpBonus burn amplifier bonus
     * @param mintCost actual mint cost paid for a mint
     */
    function _startBatchMint(
        address user,
        uint256 mintPower,
        uint256 numOfDays,
        uint256 mintableTitan,
        uint256 mintPowerBonus,
        uint256 EAABonus,
        uint256 burnAmpBonus,
        uint256 count,
        uint256 mintCost
    ) internal {
        uint256 gMintPower = s_globalMintPower;
        uint256 currentTRank = s_globalTRank;
        uint256 gMinting = s_globalTitanMinting;

        for (uint256 i = 0; i < count; i++) {
            gMintPower += mintPower;
            gMinting += _startMint(
                user,
                mintPower,
                numOfDays,
                mintableTitan,
                mintPowerBonus,
                EAABonus,
                burnAmpBonus,
                gMintPower,
                ++currentTRank,
                mintCost
            );
        }
        _updateMintStats(currentTRank, gMintPower, gMinting);
    }

    /** @dev create new mint in a batch of up to max 100 mints with different mint length
     * @param user user address
     * @param mintPower mint power
     * @param minDay minimum start day
     * @param maxDay maximum end day
     * @param dayInterval days interval between each new mint length
     * @param countPerInterval number of mint(s) to create in each mint length interval
     * @param mintableTitan mintable titan
     * @param mintPowerBonus mint power bonus
     * @param EAABonus EAA bonus
     * @param burnAmpBonus burn amplifier bonus
     * @param mintCost actual mint cost paid for a mint
     */
    function _startbatchMintLadder(
        address user,
        uint256 mintPower,
        uint256 minDay,
        uint256 maxDay,
        uint256 dayInterval,
        uint256 countPerInterval,
        uint256 mintableTitan,
        uint256 mintPowerBonus,
        uint256 EAABonus,
        uint256 burnAmpBonus,
        uint256 mintCost
    ) internal {
        uint256 gMintPower = s_globalMintPower;
        uint256 currentTRank = s_globalTRank;
        uint256 gMinting = s_globalTitanMinting;

        /**first for loop is used to determine mint length
         * minDay is the starting mint length
         * maxDay is the max mint length where it stops
         * dayInterval increases the minDay for the next mint
         */
        for (; minDay <= maxDay; minDay += dayInterval) {
            /**first for loop is used to determine mint length
             * second for loop is to create number mints per mint length
             */
            for (uint256 j = 0; j < countPerInterval; j++) {
                gMintPower += mintPower;
                gMinting += _startMint(
                    user,
                    mintPower,
                    minDay,
                    mintableTitan,
                    mintPowerBonus,
                    EAABonus,
                    burnAmpBonus,
                    gMintPower,
                    ++currentTRank,
                    mintCost
                );
            }
        }
        _updateMintStats(currentTRank, gMintPower, gMinting);
    }

    /** @dev update variables
     * @param currentTRank current tRank
     * @param gMintPower current global mint power
     * @param gMinting current global minting
     */
    function _updateMintStats(uint256 currentTRank, uint256 gMintPower, uint256 gMinting) internal {
        s_globalTRank = currentTRank;
        s_globalMintPower = gMintPower;
        s_globalTitanMinting = gMinting;
    }

    /** @dev calculate reward for claim mint or burn mint.
     * Claim mint has maturity check while burn mint would bypass maturity check.
     * @param user user address
     * @param id mint id
     * @param action claim mint or burn mint
     * @return reward calculated final reward after all bonuses and penalty (if any)
     */
    function _claimMint(
        address user,
        uint256 id,
        MintAction action
    ) internal returns (uint256 reward) {
        uint256 tRank = s_addressMIdToTRankInfo[user][id].tRank;
        uint256 gMintPower = s_addressMIdToTRankInfo[user][id].gMintPower;
        if (tRank == 0) revert TitanX_NoMintExists();

        UserMintInfo memory mint = s_tRankToMintInfo[tRank];
        if (mint.status == MintStatus.CLAIMED) revert TitanX_MintHasClaimed();
        if (mint.status == MintStatus.BURNED) revert TitanX_MintHasBurned();

        //Only check maturity for claim mint action, burn mint bypass this check
        if (mint.maturityTs > block.timestamp && action == MintAction.CLAIM)
            revert TitanX_MintNotMature();

        s_globalTitanMinting -= mint.mintableTitan;
        reward = _calculateClaimReward(user, tRank, gMintPower, mint, action);
    }

    /** @dev calculate reward up to 100 claims for batch claim function. Only calculate active and matured mints.
     * @param user user address
     * @return reward total batch claims final calculated reward after all bonuses and penalty (if any)
     */
    function _batchClaimMint(address user) internal returns (uint256 reward) {
        uint256 maxId = s_addressMId[user];
        uint256 claimCount;
        uint256 tRank;
        uint256 gMinting;
        UserMintInfo memory mint;

        for (uint256 i = 1; i <= maxId; i++) {
            tRank = s_addressMIdToTRankInfo[user][i].tRank;
            mint = s_tRankToMintInfo[tRank];
            if (mint.status == MintStatus.ACTIVE && block.timestamp >= mint.maturityTs) {
                reward += _calculateClaimReward(
                    user,
                    tRank,
                    s_addressMIdToTRankInfo[user][i].gMintPower,
                    mint,
                    MintAction.CLAIM
                );

                gMinting += mint.mintableTitan;
                ++claimCount;
            }

            if (claimCount == 100) break;
        }

        s_globalTitanMinting -= gMinting;
    }

    /** @dev calculate final reward with bonuses and penalty (if any)
     * @param user user address
     * @param tRank mint's tRank
     * @param gMintPower mint's gMintPower
     * @param userMintInfo mint's info
     * @param action claim mint or burn mint
     * @return reward calculated final reward after all bonuses and penalty (if any)
     */
    function _calculateClaimReward(
        address user,
        uint256 tRank,
        uint256 gMintPower,
        UserMintInfo memory userMintInfo,
        MintAction action
    ) private returns (uint256 reward) {
        if (action == MintAction.CLAIM) s_tRankToMintInfo[tRank].status = MintStatus.CLAIMED;
        if (action == MintAction.BURN) s_tRankToMintInfo[tRank].status = MintStatus.BURNED;

        uint256 penaltyAmount;
        uint256 penalty;
        uint256 bonus;

        //only calculate penalty when current block timestamp > maturity timestamp
        if (block.timestamp > userMintInfo.maturityTs) {
            penalty = calculateClaimMintPenalty(block.timestamp - userMintInfo.maturityTs);
        }

        //Only Claim action has mintPower bonus
        if (action == MintAction.CLAIM) {
            bonus = calculateMintPowerBonus(
                userMintInfo.mintPowerBonus,
                userMintInfo.mintPower,
                gMintPower,
                s_globalMintPower
            );
        }

        //mintPowerBonus has scaling factor of 1e7, so divide by 1e7
        reward = uint256(userMintInfo.mintableTitan) + (bonus / SCALING_FACTOR_1e7);
        penaltyAmount = (reward * penalty) / 100;
        reward -= penaltyAmount;

        if (action == MintAction.CLAIM) ++s_globalMintClaim;
        if (action == MintAction.BURN) ++s_globalMintBurn;
        if (penaltyAmount != 0) s_globalTitanMintPenalty += penaltyAmount;

        //only stored minted amount for claim mint
        if (action == MintAction.CLAIM) s_tRankToMintInfo[tRank].mintedTitan = uint128(reward);

        emit MintClaimed(user, tRank, reward, penalty, penaltyAmount);
    }

    //views
    /** @notice Returns the latest Mint Id of an address
     * @param user address
     * @return mId latest mint id
     */
    function getUserLatestMintId(address user) public view returns (uint256) {
        return s_addressMId[user];
    }

    /** @notice Returns mint info of an address + mint id
     * @param user address
     * @param id mint id
     * @return mintInfo user mint info
     */
    function getUserMintInfo(
        address user,
        uint256 id
    ) public view returns (UserMintInfo memory mintInfo) {
        return s_tRankToMintInfo[s_addressMIdToTRankInfo[user][id].tRank];
    }

    /** @notice Return all mints info of an address
     * @param user address
     * @return mintInfos all mints info of an address including mint id, tRank and gMintPower
     */
    function getUserMints(address user) public view returns (UserMint[] memory mintInfos) {
        uint256 count = s_addressMId[user];
        mintInfos = new UserMint[](count);

        for (uint256 i = 1; i <= count; i++) {
            mintInfos[i - 1] = UserMint({
                mId: i,
                tRank: s_addressMIdToTRankInfo[user][i].tRank,
                gMintPower: s_addressMIdToTRankInfo[user][i].gMintPower,
                mintInfo: getUserMintInfo(user, i)
            });
        }
    }

    /** @notice Return total mints burned
     * @return totalMintBurned total mints burned
     */
    function getTotalMintBurn() public view returns (uint256) {
        return s_globalMintBurn;
    }

    /** @notice Return current gobal tRank
     * @return globalTRank global tRank
     */
    function getGlobalTRank() public view returns (uint256) {
        return s_globalTRank;
    }

    /** @notice Return current gobal mint power
     * @return globalMintPower global mint power
     */
    function getGlobalMintPower() public view returns (uint256) {
        return s_globalMintPower;
    }

    /** @notice Return total mints claimed
     * @return totalMintClaimed total mints claimed
     */
    function getTotalMintClaim() public view returns (uint256) {
        return s_globalMintClaim;
    }

    /** @notice Return total active mints (exluded claimed and burned mints)
     * @return totalActiveMints total active mints
     */
    function getTotalActiveMints() public view returns (uint256) {
        return s_globalTRank - s_globalMintClaim - s_globalMintBurn;
    }

    /** @notice Return total minting titan
     * @return totalMinting total minting titan
     */
    function getTotalMinting() public view returns (uint256) {
        return s_globalTitanMinting;
    }

    /** @notice Return total titan penalty
     * @return totalTitanPenalty total titan penalty
     */
    function getTotalMintPenalty() public view returns (uint256) {
        return s_globalTitanMintPenalty;
    }
}
