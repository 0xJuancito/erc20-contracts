// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "src/lib/Token.sol";
import "./IGauge.sol";
import "./IPool.sol";

interface IBribe is IPool {
    /**
     * @dev This method is called when someone vote/harvest from/to a @param gauge,
     * and when this IBribe happens to be attached to the gauge.
     *
     * Attachment can happen without IBribe's permission. Implementations must verify that @param gauge is correct.
     *
     * Returns balance deltas; their net differences are credited as bribe.
     * deltaExternal must be zero or negative; Vault will take specified amounts from the contract's balance
     *
     * @param  gauge  the gauge to bribe for.
     * @param  elapsed  elapsed time after last call; can be used to save gas.
     * @return bribeTokens list of tokens to bribe
     * @return deltaGauge same order as bribeTokens, the desired change of gauge balance
     * @return deltaPool same order as bribeTokens, the desired change of pool balance
     * @return deltaExternal same order as bribeTokens, the vault will pull this amount out from the bribe contract with transferFrom()
     */
    function velocore__bribe(IGauge gauge, uint256 elapsed)
        external
        returns (
            Token[] memory bribeTokens,
            int128[] memory deltaGauge,
            int128[] memory deltaPool,
            int128[] memory deltaExternal
        );

    function bribeTokens(IGauge gauge) external view returns (Token[] memory);
    function bribeRates(IGauge gauge) external view returns (uint256[] memory);
}
