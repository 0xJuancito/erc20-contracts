// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

///@notice The owner will always be a multisig wallet.


/* -------------------------------------------------------------------------- */
/*                                   errors                                   */
/* -------------------------------------------------------------------------- */
error InsufficientEth();
error EpisodeDoesNotExist();
error EpisodeAlreadyPurchased();
error NotOwnerOrAdmin();
error SignerCannotBeZeroAddress();
error InvalidSignature();
error VoucherExpired();
error CannotPurchaseWithoutSignerApproval();

/* -------------------------------------------------------------------------- */
/*                               KillerWhalesS1                               */
/* -------------------------------------------------------------------------- */
/**
 * @title Contract for purchasing episodes for Season 1 of KillerWhales using HelloToken
 * @author 0xSimon
 */
contract KillerWhalesS1 is Ownable {
    using ECDSA for bytes32;

    /* -------------------------------------------------------------------------- */
    /*                                   events                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice emits when an episode is purchased by a user
     */
    event EpisodesPurchased(address indexed user, uint256[] episode);
    event SeasonPassPurchased(address indexed user);
    event SignerChanged(address signer);
    event SignerOnlyChanged(bool signerOnly);
    event PricePerEpisodeChanged(uint256 pricePerEpisode);

    /* -------------------------------------------------------------------------- */
    /*                                   statse                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @dev The max episodeID (i.e. available episodes 0, 1, ..., 4)
     */
    uint256 private constant MAX_EPISODE_ID = 4;

    /**
     * @notice The Bitpos if a user owns the season pass
     */
    uint256 private constant OWNS_SEASON_PASS_BITPOS = (1 << 255);

    /**
     * @notice The HelloToken contract
     */
    IERC20 public immutable HELLO_TOKEN;

    /**
     * @notice The price per episode
     */

    uint256 public pricePerEpisode = 1 ether;

    /**
     * @notice The signer providing signatures for discounts on episodes
     */
    address public signer;

    /**
     * @notice if true, episodes can only be purchased through signatures
     */
    bool public signerOnly;

    /**
     * @notice A mapping that stores purchased episodes for every user
     * @dev Maps between an address to a bitmap that contains purchased episodes
     * @dev Assumptions:
     *     - There are only 5 episodes in Season 1 therefore the bitmap can never overflow
     * Examples:
     *     - If a user has purchased episode 0, the bitmap would look like:
     *                          00000001
     *     - If a user has purchased episodes 1 & 3, the bitmap would look like:
     *                          00001010
     */
    mapping(address => uint256) public episodePurchasedBitmap;

    /* -------------------------------------------------------------------------- */
    /*                                 constructor                                */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Deploys the contract and saves the HelloToken contract address and the signer
     * @dev `msg.sender` is assigned to the owner, pay attention if this contract is deployed via another contract
     * @param _helloToken The address of HelloToken
     * @param _signer Address of the discount signer
     */
    constructor(address _helloToken, address _signer) {
        HELLO_TOKEN = IERC20(_helloToken);
        if (_signer == address(0)) {
            _revert(SignerCannotBeZeroAddress.selector);
        }
        signer = _signer;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  external                                  */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Purchase episodes without discount
     * @notice HelloTokens will be transferred to this contract
     * @notice Ensure approvals for HelloToken has been set
     * @param episodeIds the episodeIDs to be purchased
     * @dev Reverts if the any of the episodes in the argument has been purchased already
     * @dev Reverts if the any of the episodes in the argument does not exist (i.e. > MAX_EPISODE_ID)
     */
    function purchaseEpisodesNoDiscount(uint256[] calldata episodeIds) external {
        if (signerOnly) {
            _revert(CannotPurchaseWithoutSignerApproval.selector);
        }

        // calculate total price
        uint256 __totalPrice = episodeIds.length * pricePerEpisode;

        // update state
        _grantEpisodes(msg.sender, episodeIds);

        // transfer tokens
        HELLO_TOKEN.transferFrom(msg.sender, address(this), __totalPrice);
    }

    /**
     * @notice Purchase espidoes with discount
     * @notice HelloTokens will be transferred to this contract
     * @notice Ensure approvals for HelloToken has been set
     * @param episodeIds the episodeIDs to be purchased
     * @param _discount the discount to be applied in basisPoint (e.g. 500 for 5% discount)
     * @param _expirationTimestamp the expiration timestamp for which this discount can be applied
     * @param signature the signature signed by `signer`
     */
    function purchaseEpisodeWithDiscount(
        uint256[] calldata episodeIds,
        uint256 _discount,
        uint256 _expirationTimestamp,
        bytes calldata signature
    ) external {
        if (signerOnly) {
            _revert(CannotPurchaseWithoutSignerApproval.selector);
        }

        // check signature
        _checkDiscountSignature(episodeIds, _discount, _expirationTimestamp, signature);

        // calculate total price - discount
        uint256 __totalPrice = episodeIds.length * pricePerEpisode * (10_000 - _discount) / 10_000;

        // update state
        _grantEpisodes(msg.sender, episodeIds);

        // transfer tokens
        HELLO_TOKEN.transferFrom(msg.sender, address(this), __totalPrice);
    }

    /// @notice Purchase episodes with a total price and signature
    /// @notice HelloTokens will be transferred to this contract
    /// @notice grant episodes to the user
    /// @param episodeIds the episodeIDs to be purchased
    /// @param totalPrice the total price of the episodes
    /// @param _expirationTimestamp the expiration timestamp for which this price is applied
    /// @param signature the signature signed by `signer`
    function purchaseEpisodesSignatureOnly(
        uint256[] calldata episodeIds,
        uint256 totalPrice,
        uint256 _expirationTimestamp,
        bytes calldata signature
    ) external {
        // check signature
        _checkTotalPriceSignature(episodeIds, totalPrice, _expirationTimestamp, signature);

        // update state
        _grantEpisodes(msg.sender, episodeIds);

        // transfer tokens
        HELLO_TOKEN.transferFrom(msg.sender, address(this), totalPrice);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    owner                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Owner only - Updates the address of the discount signer
     * @param _signer Address of the discount signer
     */
    function setSigner(address _signer) external onlyOwner {
        if (_signer == address(0)) {
            _revert(SignerCannotBeZeroAddress.selector);
        }
        signer = _signer;

        emit SignerChanged(_signer);
    }

    /**
     * @notice Owner only - Updates the signerOnly flag
     * @param _signerOnly if true, episodes can only be purchased through signatures
     */
    function setSignerOnly(bool _signerOnly) external onlyOwner {
        signerOnly = _signerOnly;

        emit SignerOnlyChanged(_signerOnly);
    }

    /**
     * @notice Owner only - Updates the price per episode
     * @param _price Price per episode
     */
    function setPricePerEpisode(uint256 _price) external onlyOwner {
        pricePerEpisode = _price;

        emit PricePerEpisodeChanged(_price);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    views                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Returns the episodes purchased by the supplied address
     * @param account The address to check
     */
    function episodesOfOwner(address account) external view returns (uint256[] memory) {
        uint256[] memory episodes = new uint256[](MAX_EPISODE_ID+1);
        uint256 map = episodePurchasedBitmap[account];
        uint256 count;
        assembly {
            let i := 0
            let len := add(MAX_EPISODE_ID, 1)
            for {} lt(i, len) { i := add(i, 1) } {
                // Check if the bit is set
                if gt(and(map, shl(i, 1)), 0) {
                    count := add(count, 1)
                    mstore(add(episodes, mul(count, 0x20)), i)
                }
            }
        }

        // Resizing the array according to the count
        assembly {
            mstore(episodes, count)
        }
        return episodes;
    }

    function isSeasonPassHolder(address account) external view returns (bool) {
        return _isSeasonPassHolder(episodePurchasedBitmap[account]);
    }

    function _isSeasonPassHolder(uint256 bitmap) internal pure returns (bool) {
        return (bitmap & OWNS_SEASON_PASS_BITPOS) != 0;
    }

    /**
     * @notice Returns whether an episode has been purchased by the supplied address
     * @param account The address to check
     * @param account The episodeId to check
     * @dev Reverts if an episode does not exist (i.e. > MAX_EPISODE_ID)
     */
    function ownsEpisode(address account, uint256 episodeId) external view returns (bool) {
        if (episodeId > MAX_EPISODE_ID) {
            _revert(EpisodeDoesNotExist.selector);
        }
        uint256 map = episodePurchasedBitmap[account];
        if (_isSeasonPassHolder(map)) {
            return true;
        }
        return (map & (1 << episodeId)) != 0;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  internal                                  */
    /* -------------------------------------------------------------------------- */
    function _revert(bytes4 code) internal pure {
        assembly {
            mstore(0x0, code)
            revert(0x0, 0x04)
        }
    }

    /**
     * @dev Checks whether a signature is valid for discount on purchase
     * @dev Reverts if now > expirationTimestamp
     * @dev Reverts if the signature is invalid
     * @param _discount the discount in basis point (e.g. 500 for 5% discount)
     * @param _expirationTimestamp the expiration timestamp for which this discount can be applied
     * @param signature the signature
     */
    function _checkDiscountSignature(
        uint256[] memory episodeIds,
        uint256 _discount,
        uint256 _expirationTimestamp,
        bytes memory signature
    ) internal view {
        bytes32 hash = keccak256(
            abi.encodePacked(
                msg.sender, episodeIds, _discount, block.chainid, address(this), _expirationTimestamp, "discount"
            )
        );

        if (block.timestamp > _expirationTimestamp) {
            _revert(VoucherExpired.selector);
        }
        if (hash.toEthSignedMessageHash().recover(signature) != signer) {
            _revert(InvalidSignature.selector);
        }
    }

    /**
     * @dev Checks whether a signature is valid for price  on purchase
     * @dev Reverts if now > expirationTimestamp
     * @dev Reverts if the signature is invalid
     * @param _totalPrice the total price for all the episodes
     * @param _expirationTimestamp the expiration timestamp for which this discount can be applied
     * @param signature the signature
     */
    function _checkTotalPriceSignature(
        uint256[] memory episodeIds,
        uint256 _totalPrice,
        uint256 _expirationTimestamp,
        bytes memory signature
    ) internal view {
        bytes32 hash = keccak256(
            abi.encodePacked(
                msg.sender, episodeIds, _totalPrice, block.chainid, address(this), _expirationTimestamp, "totalPrice"
            )
        );

        if (block.timestamp > _expirationTimestamp) {
            _revert(VoucherExpired.selector);
        }
        if (hash.toEthSignedMessageHash().recover(signature) != signer) {
            _revert(InvalidSignature.selector);
        }
    }

    /**
     * @dev Updates episodePurchasedBitmap for a user
     * @dev Reverts if any of the episodes does not exist
     * @dev Reverts if any of the episodes has been been purchased
     * @param user the address to be updated
     * @param episodeIds the IDs of the purchased episodes
     */
    function _grantEpisodes(address user, uint256[] memory episodeIds) internal {
        uint256 existingEpisodeBitmap = episodePurchasedBitmap[user];
        uint256 newEpisodeBitmap = existingEpisodeBitmap;

        // loop, check episodeId
        for (uint256 i; i < episodeIds.length;) {
            uint256 episodeId = episodeIds[i];

            // episode doesn't exist
            if (episodeId > MAX_EPISODE_ID) {
                _revert(EpisodeDoesNotExist.selector);
            }
            uint256 shiftedEpisodeId = 1 << episodeId;

            //buying 5 episodes is equivalent to buying the season pass, therefore, the episode CAN be repurchased only in this specific case.
            if (episodeIds.length != MAX_EPISODE_ID + 1) {
                // episode already purchased
                if ((existingEpisodeBitmap & shiftedEpisodeId) != 0) {
                    _revert(EpisodeAlreadyPurchased.selector);
                }
            }

            // update bitmap
            newEpisodeBitmap |= shiftedEpisodeId;

            // next loop
            unchecked {
                ++i;
            }
        }

        // got all episodes => season pass
        if (episodeIds.length == MAX_EPISODE_ID + 1) {
            newEpisodeBitmap |= OWNS_SEASON_PASS_BITPOS;
            emit SeasonPassPurchased(user);
        }

        // update
        episodePurchasedBitmap[user] = newEpisodeBitmap;

        emit EpisodesPurchased(user, episodeIds);
    }
}
