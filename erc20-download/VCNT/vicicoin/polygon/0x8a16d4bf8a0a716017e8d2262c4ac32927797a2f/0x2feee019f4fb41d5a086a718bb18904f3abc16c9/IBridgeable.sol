// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "AccessConstants.sol";

struct BridgeArgs {
    address caller;
    address fromAddress;
    address toAddress;
    uint256 remoteChainId;
    uint256 itemId;
    uint256 amount;
}

struct SendParams {
    address fromAddress;
    uint256 dstChainId;
    address toAddress;
    uint256 itemId;
    uint256 amount;
}

/**
 * @title Bridgeable Interface
 * @dev common interface for bridgeable tokens
 */
interface IBridgeable {
    event SentToBridge(
        address indexed fromAddress,
        address indexed toAddress,
        uint256 indexed itemId,
        uint256 amount,
        address caller,
        uint256 dstChainId
    );

    event ReceivedFromBridge(
        address indexed fromAddress,
        address indexed toAddress,
        uint256 indexed itemId,
        uint256 amount,
        address caller,
        uint256 srcChainId
    );

    /**
     * @dev Callback function to notify when tokens have been sent through a bridge.
     * @dev Implementations SHOULD either lock or burn these tokens.
     * @param args.caller the original message sender
     * @param args.fromAddress the owner of the tokens that were sent
     * @param args.toAddress the destination address on the other chain
     * @param args.remoteChainId the chain id for the destination
     * @param args.itemId the token id for ERC721 or ERC1155 tokens. Ignored for ERC20 tokens.
     * @param args.amount the amount of tokens sent for ERC20 and ERC1155 tokens. Ignored for ERC721 tokens.
     */
    function sentToBridge(BridgeArgs calldata args) external payable;

    /**
     * @dev Callback function to notify when tokens have been sent through a bridge.
     * @dev Implementations SHOULD either unlock or mint these tokens and send them to the `toAddress`.
     * @dev IMPORTANT: access to this function MUST be tightly controlled. Otherwise it's an infinite free tokens function.
     * @param args.caller the original message sender
     * @param args.fromAddress the owner of the tokens that were sent
     * @param args.toAddress the destination address on this chain
     * @param args.srcChainId the chain id for the source
     * @param args.itemId the token id for ERC721 or ERC1155 tokens. Ignored for ERC20 tokens.
     * @param args.amount the amount of tokens sent for ERC20 and ERC1155 tokens. Ignored for ERC721 tokens.
     */
    function receivedFromBridge(BridgeArgs calldata args) external payable;
}
