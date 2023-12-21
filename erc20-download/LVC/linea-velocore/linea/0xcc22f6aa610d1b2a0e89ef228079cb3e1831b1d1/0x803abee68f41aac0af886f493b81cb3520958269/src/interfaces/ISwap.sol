// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "src/lib/Token.sol";
import "./IPool.sol";

interface ISwap is IPool {
    /**
     * @param user the user that requested swap
     * @param tokens sorted, unique list of tokens that user asked to swap
     * @param amounts same order as tokens, requested change of token balance, positive when pool receives, negative when pool gives. type(int128).max for unknown values, for which the pool should decide.
     * @param data auxillary data for pool-specific uses.
     * @return deltaGauge same order as tokens, the desired change of gauge balance
     * @return deltaPool same order as bribeTokens, the desired change of pool balance
     */
    function velocore__execute(address user, Token[] calldata tokens, int128[] memory amounts, bytes calldata data)
        external
        returns (int128[] memory, int128[] memory);
    function swapType() external view returns (string memory);
    function listedTokens() external view returns (Token[] memory);
    function lpTokens() external view returns (Token[] memory);
    function underlyingTokens(Token lp) external view returns (Token[] memory);
    //function spotPrice(Token token, Token base) external view returns (uint256);
}
