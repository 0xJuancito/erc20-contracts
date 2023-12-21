// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.17;

library EncodingUtils {
    /**
     * @dev Computes the hash of a transfer request
     * Enables to index requests in mappings
     * NB : block timestamp is included in the computation
     */
    function encodeRequest(
        address _from,
        address _to,
        uint256 _value,
        uint256 counter
    ) internal view returns (bytes32) {
        return
            // solhint-disable-next-line not-rely-on-time
            keccak256(abi.encode(block.timestamp, _from, _to, _value, counter));
    }
}
