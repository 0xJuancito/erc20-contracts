pragma solidity 0.8.17;

library EncodingUtils {
    function encodeRequest(
        address _from,
        address _to,
        uint256 _value,
        uint256 counter
    ) internal view returns (bytes32) {
        return
            keccak256(abi.encode(block.timestamp, _from, _to, _value, counter));
    }
}
