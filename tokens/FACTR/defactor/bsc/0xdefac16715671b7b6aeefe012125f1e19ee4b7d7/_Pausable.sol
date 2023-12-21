// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

/**
 * @dev Pausing logic that includes whether the pause was initiated by an attorney.
 *
 * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
 */
abstract contract Pausable {
    struct PauseState {
        bool paused;
        bool pausedByAttorney;
    }

    PauseState private pauseState;

    event Paused(address account, bool attorney);
    event Unpaused(address account);

    constructor() {
        pauseState = PauseState(false, false);
    }

    modifier whenNotPaused() {
        require(!pauseState.paused);
        _;
    }

    modifier whenPaused() {
        require(pauseState.paused);
        _;
    }

    function paused() public view returns (bool) {
        return pauseState.paused;
    }

    /**
     * @dev Check if the pause was initiated by an attorney.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function pausedByAttorney() public view returns (bool) {
        return pauseState.paused && pauseState.pausedByAttorney;
    }

    /**
     * @dev Internal logic for pausing the contract.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function _pause(bool attorney) internal {
        pauseState.paused = true;
        pauseState.pausedByAttorney = attorney;
        emit Paused(msg.sender, attorney);
    }

    /**
     * @dev Internal logic for unpausing the contract.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function _unpause() internal {
        pauseState.paused = false;
        pauseState.pausedByAttorney = false;
        emit Unpaused(msg.sender);
    }
}
