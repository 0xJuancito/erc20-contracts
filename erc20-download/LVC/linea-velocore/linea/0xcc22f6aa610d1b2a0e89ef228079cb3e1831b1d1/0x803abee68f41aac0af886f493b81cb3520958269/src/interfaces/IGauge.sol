// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "src/lib/Token.sol";
import "src/interfaces/IPool.sol";

/**
 * Gauges are just pools.
 * instead of velocore__execute, they interact with velocore__gauge.
 * (un)staking is done by putting/extracting staking token (usually LP token) from/into the pool with velocore__gauge.
 * harvesting is done by setting the staking amount to zero.
 */
interface IGauge is IPool {
    /**
     * @dev This method is called by Vault.execute().
     * the parameters and return values are the same as velocore__execute.
     * The only difference is that the vault will call velocore__emission before calling velocore__gauge.
     */
    function velocore__gauge(address user, Token[] calldata tokens, int128[] memory amounts, bytes calldata data)
        external
        returns (int128[] memory deltaGauge, int128[] memory deltaPool);

    /**
     * @dev This method is called by Vault.execute() before calling velocore__emission or changing votes.
     *
     * The vault will credit emitted VC into the gauge balance.
     * IGauge is expected to update its internal ledger.
     * @param newEmissions newly emitted VCs since last emission
     */
    function velocore__emission(uint256 newEmissions) external;

    function stakeableTokens() external view returns (Token[] memory);
    function stakedTokens(address user) external view returns (uint256[] memory);
    function stakedTokens() external view returns (uint256[] memory);
    function emissionShare(address user) external view returns (uint256);
    function naturalBribes() external view returns (Token[] memory);
}
