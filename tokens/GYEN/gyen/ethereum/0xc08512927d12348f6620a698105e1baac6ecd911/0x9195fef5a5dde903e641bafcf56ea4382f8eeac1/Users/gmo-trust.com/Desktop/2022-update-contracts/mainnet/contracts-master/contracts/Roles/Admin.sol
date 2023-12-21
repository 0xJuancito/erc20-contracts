pragma solidity 0.5.8;

import "./Capper.sol";
import "./Pauser.sol";
import "./Prohibiter.sol";

contract Admin is Capper, Prohibiter {
    address public admin = address(0);

    event CapperChanged(address indexed oldCapper, address indexed newCapper, address indexed sender);
    event PauserChanged(address indexed oldPauser, address indexed newPauser, address indexed sender);
    event ProhibiterChanged(address indexed oldProhibiter, address indexed newProhibiter, address indexed sender);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "the sender is not the admin");
        _;
    }

    function changeCapper(address _account) public onlyAdmin whenNotPaused isNotZeroAddress(_account) {
        address old = capper;
        capper = _account;
        emit CapperChanged(old, capper, msg.sender);
    }

    /**
     * Change Pauser
     * @dev "whenNotPaused" modifier should not be used here
     */
    function changePauser(address _account) public onlyAdmin isNotZeroAddress(_account) {
        address old = pauser;
        pauser = _account;
        emit PauserChanged(old, pauser, msg.sender);
    }

    function changeProhibiter(address _account) public onlyAdmin whenNotPaused isNotZeroAddress(_account) {
        address old = prohibiter;
        prohibiter = _account;
        emit ProhibiterChanged(old, prohibiter, msg.sender);
    }
}