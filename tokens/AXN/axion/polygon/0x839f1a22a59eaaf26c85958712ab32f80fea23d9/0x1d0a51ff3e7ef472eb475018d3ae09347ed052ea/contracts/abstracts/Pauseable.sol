// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import './Manageable.sol';

abstract contract Pauseable is Manageable {
    event SetPaused(bool paused);

    bool internal paused;
    mapping(address => bool) public _whitelist;

    modifier whenNotPaused(address sender) {
        require(
            paused == false || hasRole(MANAGER_ROLE, sender) || _whitelist[sender],
            'Function is paused'
        );
        _;
    }

    function setPaused(bool _paused) external {
        require(hasRole(MANAGER_ROLE, msg.sender), 'Caller must be manager');

        paused = _paused;
        emit SetPaused(_paused);
    }

    function getPaused() external view returns (bool) {
        return paused;
    }

    function setWhiteListedAddress(address _address, bool _whitelisted) external onlyManager {
        _whitelist[_address] = _whitelisted;
    }
}
