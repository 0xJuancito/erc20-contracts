//SPDX-License-Identifier: Apache License Version 2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IERC20Receiver is IERC165 {
    /**
        @dev Handles the receipt of a single ERC20 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC20Received(address,address,uint256,bytes)"))`
        (i.e. its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC20Received(address,address,uint256,bytes)"))` if transfer is allowed
    */
    function onERC20Received(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}
