// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/**
 * Context variant with ERC2771 support.
 * This contract is similar to oz:ERC2771Context.sol
 */

abstract contract ERC2771 is Context {
    address public trustedForwarder;

    event SetForwarder(address indexed forwarder);

    function setForwarder(address forwarder) public virtual {
        trustedForwarder = forwarder;
        emit SetForwarder(forwarder);
    }

    function isTrustedForwarder(address forwarder) public view returns (bool) {
        return forwarder == trustedForwarder;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender) && msg.data.length >= 20) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data

            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }
}
