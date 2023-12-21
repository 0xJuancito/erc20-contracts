// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.8;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IFeeLogic.sol";

contract FeeRegistry is Initializable, OwnableUpgradeable {
    mapping(address => bool) public feeLogics;
    address[] public feeLogicAddresses;


    function initialize() public initializer {
        __Ownable_init();
    }

    function addFeeLogic(address[] memory logics) external onlyOwner {
        for (uint i = 0; i < logics.length; i++) {
            feeLogics[logics[i]] = true;
            feeLogicAddresses.push(logics[i]);
        }
    }

    function removeFeeLogic(address logic) external onlyOwner {
        feeLogics[logic] = false;
        for (uint i = 0; i < feeLogicAddresses.length; i++) {
            if (feeLogicAddresses[i] == logic) {
                feeLogicAddresses[i] = feeLogicAddresses[feeLogicAddresses.length - 1];
                feeLogicAddresses.pop();
                break;
            }
        }
    }

    function shouldApplyFees(address from, address to) external view returns (bool) {
        for (uint i = 0; i < feeLogicAddresses.length; i++) {
            address logicAddress = feeLogicAddresses[i];
            if (IFeeLogic(logicAddress).shouldApplyFees(from, to)) {
                return true;
            }
        }
        return false;
    }

}