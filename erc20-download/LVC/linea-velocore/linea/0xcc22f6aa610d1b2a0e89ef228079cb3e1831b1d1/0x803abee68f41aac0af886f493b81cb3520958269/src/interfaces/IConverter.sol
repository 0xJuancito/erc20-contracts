// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "src/lib/Token.sol";

interface IConverter {
    /**
     * @dev This method is called by Vault.execute().
     * Vault will transfer any positively specified amounts directly to the IConverter before calling velocore__convert.
     *
     * Instead of returning balance delta numbers, IConverter is expected to directly transfer outputs back to vault.
     * Vault will measure the difference, and credit the user.
     */
    function velocore__convert(address user, Token[] calldata tokens, int128[] memory amounts, bytes calldata data)
        external;
}
