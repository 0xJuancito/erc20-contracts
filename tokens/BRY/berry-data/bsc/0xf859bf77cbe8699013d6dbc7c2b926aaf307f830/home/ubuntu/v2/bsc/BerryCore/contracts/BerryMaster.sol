pragma solidity ^0.5.0;

import "./BerryGetters.sol";

/**
* @title Berry Master
* @dev This is the Master contract with all berry getter functions and delegate call to Berry.
* The logic for the functions on this contract is saved on the BerryGettersLibrary, BerryTransfer,
* BerryGettersLibrary, and BerryStake
*/
contract BerryMaster is BerryGetters {
    event NewBerryAddress(address _newBerry);

    /**
    * @dev The constructor sets the original `berryStorageOwner` of the contract to the sender
    * account, the berry contract to the Berry master address and owner to the Berry master owner address
    * @param _berryContract is the address for the berry contract
    */
    constructor(address _berryContract) public {
        berry.init();
        berry.addressVars[keccak256("_owner")] = msg.sender;
        berry.addressVars[keccak256("_deity")] = msg.sender;
        berry.addressVars[keccak256("berryContract")] = _berryContract;
        emit NewBerryAddress(_berryContract);
    }

    /**
    * @dev Gets the 5 miners who mined the value for the specified requestId/_timestamp
    * @dev Only needs to be in library
    * @param _newDeity the new Deity in the contract
    */

    function changeDeity(address _newDeity) external {
        berry.changeDeity(_newDeity);
    }

    /**
    * @dev  allows for the deity to make fast upgrades.  Deity should be 0 address if decentralized
    * @param _berryContract the address of the new Berry Contract
    */
    function changeBerryContract(address _berryContract) external {
        berry.changeBerryContract(_berryContract);
    }

    /**
    * @dev This is the fallback function that allows contracts to call the berry contract at the address stored
    */
    function() external payable {
        address addr = berry.addressVars[keccak256("berryContract")];
        bytes memory _calldata = msg.data;
        assembly {
            let result := delegatecall(not(0), addr, add(_calldata, 0x20), mload(_calldata), 0, 0)
            let size := returndatasize
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)
            // revert instead of invalid() bc if the underlying call failed with invalid() it already wasted gas.
            // if the call returned error data, forward it
            switch result
                case 0 {
                    revert(ptr, size)
                }
                default {
                    return(ptr, size)
                }
        }
    }
}
