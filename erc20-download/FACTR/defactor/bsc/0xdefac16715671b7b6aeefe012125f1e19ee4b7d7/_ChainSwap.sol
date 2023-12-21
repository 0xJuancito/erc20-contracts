// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

import "./_Staking.sol";

abstract contract ChainSwap is Staking {
    uint256 public swapNonce;

    event SwapToChain(
        string toChain,
        address indexed from,
        address indexed to,
        bytes32 indexed swapId,
        uint256 value,
        uint64 stakeTime
    );
    event SwapFromChain(
        string fromChain,
        address indexed from,
        address indexed to,
        bytes32 indexed swapId,
        uint256 value,
        uint64 stakeTime
    );

    /**
     * @dev Gets an incrementing nonce for generating swap IDs.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getSwapNonce() internal returns (uint256) {
        return ++swapNonce;
    }

    /**
     * @dev Initiates a swap to another chain. Transfers the tokens to this contract and emits an event
     *      indicating the request to swap.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function swapToChain(
        string memory chain,
        address to,
        uint256 value,
        uint64 stakeTime
    ) public whenNotPaused whenUnlocked {
        bytes32 swapId = keccak256(
            abi.encodePacked(getSwapNonce(), msg.sender, to, address(this), chain, value, stakeTime)
        );

        _transfer(msg.sender, address(this), value);
        emit SwapToChain(chain, msg.sender, to, swapId, value, stakeTime);
    }

    /**
     * @dev Completes a swap from another chain, called by a swapper account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function swapFromChain(
        string memory fromChain,
        address from,
        address to,
        bytes32 swapId,
        uint256 value,
        uint64 stakeTime
    ) public whenNotPaused onlySwapper {
        _transfer(address(this), to, value);

        emit SwapFromChain(fromChain, from, to, swapId, value, stakeTime);
        if (stakeTime == 1) {
            _stake(to, value, 0);
        } else if (stakeTime > 1) {
            _stake(to, value, stakeTime);
        }
    }
}
