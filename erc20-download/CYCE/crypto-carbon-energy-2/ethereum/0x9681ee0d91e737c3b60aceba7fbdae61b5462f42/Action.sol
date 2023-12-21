// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import "./Ownable.sol";

contract Action is Ownable {
    mapping(address => bool) private _blacklist;
    bool private _pause;

    event AddBlacklist(address indexed account);
    event RemoveBlacklist(address indexed account);
    event Pause(address indexed account);
    event UnPause(address indexed account);

    constructor() {
        _pause = false;
    }



    function pause() public onlyOwner returns(bool) {
        require(!_pause, "Action: already pause");
        _pause = true;
        emit Pause(msg.sender);
        return true;
    }

    function unpause() public onlyOwner returns(bool) {
        require(_pause, "Action: already  unpause");
        _pause = false;
        emit UnPause(msg.sender);
        return true;
    }

    function paused() public view returns (bool) {
        return _pause;
    }

    function addBlacklist(
        address blackAddress
    ) public onlyOwner returns (bool) {
        require(!_blacklist[blackAddress], "Action: already blacklisted");
        _blacklist[blackAddress] = true;
        emit AddBlacklist(blackAddress);
        return true;
    }

    function removeBlacklist(
        address blackAddress
    ) public onlyOwner returns (bool) {
        require(_blacklist[blackAddress], 'Action: not blacklisted');
        _blacklist[blackAddress] = false;
        emit RemoveBlacklist(blackAddress);
        return true;
    }

    function blackListed(address account) public view returns (bool) {
        return _blacklist[account];
    }

    function _beforeTransferToken(
        address from,
        address to,
        uint256 amount
    ) internal view {
        require(!_blacklist[from], "Action: Sender blacklisted");
        require(!_blacklist[to], "Action: Recipient blacklisted");
        require(amount > 0, "Action: transfer amount has to big than 0");
        require(!_pause, "Action: paused");
    }
}
