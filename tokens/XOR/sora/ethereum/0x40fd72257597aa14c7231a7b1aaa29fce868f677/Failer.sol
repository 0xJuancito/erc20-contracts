pragma solidity ^0.5.8;

/**
 * Contract for revert cases testing
 */
contract Failer {
    /**
     * A special function-like stub to allow ether accepting. Always fails.
     */
    function() external payable {
        revert("eth transfer revert");
    }

    /**
     * Fake ERC-20 transfer function. Always fails.
     */
    function transfer(address, uint256) external pure {
        revert("ERC-20 transfer revert");
    }
}
