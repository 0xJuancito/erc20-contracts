// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

abstract contract Governable {
    address private _gov;
    address private _pendingGov;

    event ChangeGovStarted(address indexed previousGov, address indexed newGov);
    event GovChanged(address indexed previousGov, address indexed newGov);

    error Forbidden();

    modifier onlyGov() {
        _onlyGov();
        _;
    }

    constructor() {
        _changeGov(msg.sender);
    }

    function gov() public view virtual returns (address) {
        return _gov;
    }

    function pendingGov() public view virtual returns (address) {
        return _pendingGov;
    }

    function changeGov(address _newGov) public virtual onlyGov {
        _pendingGov = _newGov;
        emit ChangeGovStarted(_gov, _newGov);
    }

    function acceptGov() public virtual {
        if (msg.sender != _pendingGov) revert Forbidden();

        delete _pendingGov;
        _changeGov(msg.sender);
    }

    function _changeGov(address _newGov) internal virtual {
        address previousGov = _gov;
        _gov = _newGov;
        emit GovChanged(previousGov, _newGov);
    }

    function _onlyGov() internal view {
        if (msg.sender != _gov) revert Forbidden();
    }
}
