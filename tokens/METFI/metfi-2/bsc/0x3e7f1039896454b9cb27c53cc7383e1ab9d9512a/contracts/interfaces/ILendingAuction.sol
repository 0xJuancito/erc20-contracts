// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// @title MetFi Lending Calculator contract
// @author MetFi
// @notice This contract is responsible for auctioning liquidated loans
interface ILendingAuction is IERC721Receiver {
    //----------------- Events -------------------------------------------------

    event AuctionCreated(uint256 indexed auctionId, uint256 indexed tokenId);

    event AuctionBid(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        uint256 oldBid,
        address oldBidder,
        uint256 newBid,
        address newBidder
    );

    event AuctionClaimed(uint256 indexed auctionId, uint256 indexed tokenId);

    event AuctionLiquidated(uint256 indexed auctionId, uint256 indexed tokenId);

    event AuctionConfigurationChanged(
        AuctionConfiguration oldConfiguration,
        AuctionConfiguration newConfiguration
    );

    //----------------- Structs -------------------------------------------------

    struct AuctionInfo {
        uint256 auctionId;
        uint256 tokenId;
        uint256 currentBid;
        address currentBidder;
        uint256 liquidationDeadline;
        uint256 biddingDeadline;
        AuctionStage stage;
    }

    struct AuctionConfiguration {
        uint256 minBidIncrement;
        uint256 startingPricePercentageOfFullPrice; // 1_000_000 = 100%
    }

    enum AuctionStage {
        CREATED,
        CLAIMED,
        LIQUIDATED,
        MIGRATED
    }

    //----------------- Getters -------------------------------------------------

    function getAuctionInfo(
        uint256 auctionId
    ) external view returns (AuctionInfo memory);

    function getActiveAuctions() external view returns (AuctionInfo[] memory);

    function getAuctionsForLiquidation()
        external
        view
        returns (uint256[] memory);

    function getAuctionConfiguration()
        external
        view
        returns (AuctionConfiguration memory);

    //----------------- User functions -------------------------------------------

    function bidOnAuction(uint256 auctionId, uint256 amount) external;

    function claimAuction(uint256 auctionId) external;

    //----------------- System functions ------------------------------------------

    function liquidateAuctions(uint256[] calldata auctionId) external;

    function migrateToNewAuctionContract(
        uint256 maxAuctionsToProcess,
        address recipient
    ) external returns (uint256[] memory);

    //----------------- Errors ----------------------------------------------------

    error OnlyAuctionManager();
    error BidOnOwnBid();
    error OnlyTreasury();
    error OnlyLending();
    error AuctionDoesNotExist();
    error BlacklistedAddress();
    error InvalidAddress();
    error AuctionNotFinished();
    error AuctionFinished();
    error NoBids();
    error BidTooLow();
    error AuctionAlreadyClaimed();
    error FailsafeEnabled();
    error AuctionNotDisabledBeforeMigration();
    error OnlyRealmGuardian();
    error MigrationAlreadyFinished();
}
