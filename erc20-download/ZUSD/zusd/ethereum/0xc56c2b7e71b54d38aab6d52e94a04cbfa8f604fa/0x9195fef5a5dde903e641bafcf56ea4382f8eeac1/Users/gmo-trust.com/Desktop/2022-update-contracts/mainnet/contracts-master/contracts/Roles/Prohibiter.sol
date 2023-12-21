pragma solidity 0.5.8;

import "./Pauser.sol";

contract Prohibiter is Pauser {
    address public prohibiter = address(0);
    mapping(address => bool) public prohibiteds;

    event Prohibition(address indexed prohibited, bool status, address indexed sender);

    modifier onlyProhibiter() {
        require(msg.sender == prohibiter, "the sender is not the prohibiter");
        _;
    }

    modifier onlyNotProhibited(address _account) {
        require(!prohibiteds[_account], "this account is prohibited");
        _;
    }

    modifier onlyProhibited(address _account) {
        require(prohibiteds[_account], "this account is not prohibited");
        _;
    }

    function prohibit(address _account) public onlyProhibiter whenNotPaused isNotZeroAddress(_account) onlyNotProhibited(_account) {
        prohibiteds[_account] = true;
        emit Prohibition(_account, prohibiteds[_account], msg.sender);
    }

    function unprohibit(address _account) public onlyProhibiter whenNotPaused isNotZeroAddress(_account) onlyProhibited(_account) {
        prohibiteds[_account] = false;
        emit Prohibition(_account, prohibiteds[_account], msg.sender);
    }
}