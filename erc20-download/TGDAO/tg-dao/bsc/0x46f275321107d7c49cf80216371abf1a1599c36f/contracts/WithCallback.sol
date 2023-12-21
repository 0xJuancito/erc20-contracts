// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICallbackContract.sol";

/**
 * @dev Allows the owner to register a callback contract that will be called after every call of the transfer or burn function
 */
contract WithCallback is Ownable {

    address public registeredCallback = address(0x0);

    function registerCallback(address callback) public onlyOwner {
        registeredCallback = callback;
    }

    function unregisterCallback() public onlyOwner {
        registeredCallback = address(0x0);
    }

    function _burnCallback(address account, uint256 amount) internal {
        if (registeredCallback != address(0x0)) {
            ICallbackContract targetCallback = ICallbackContract(registeredCallback);
            targetCallback.burnCallback(account, amount);
        }
    }

    function _transferCallback(address sender, address recipient, uint256 amount) internal {
        if (registeredCallback != address(0x0)) {
            ICallbackContract targetCallback = ICallbackContract(registeredCallback);
            targetCallback.transferCallback(sender, recipient, amount);
        }
    }

}

