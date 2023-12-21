// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "./Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract VestingUpgradeable is Initializable {

    function __Vesting_init() internal onlyInitializing {
    }

    function __Vesting_init_unchained() internal onlyInitializing {
    }
   
    event VestingAccountAdded(address _vesting, uint64 _startTime, uint64 _releaseDuration, uint64 _lockDuration);
    
    event ReleaseVestingAmount(address _vesting, address _beneficiary, uint256 _amount);

    struct Beneficiary {
        uint64 startTime;
        uint64 lockDuration;
        uint64 releaseDuration;
        uint256 released;
    }
    
    mapping(address => Beneficiary) private vestingBeneficiary;
    mapping(address => bool) private vestingAccountAdded;

    function _addVestingAndBeneficiary(address _vesting, uint64 _startTime, uint64 _releaseDuration, uint64 _lockDuration) internal virtual returns(bool success) {
       
        require(_vesting != address(0), "Vesting Account can not be zero");
       
        require(!vestingAccountAdded[_vesting], "Account Already added");
        
        Beneficiary memory beneficiary = Beneficiary(_startTime, _lockDuration, _releaseDuration, 0);
        vestingAccountAdded[_vesting]=true;
        vestingBeneficiary[_vesting] = beneficiary;

        return true;
    }
    
    function getVestingAccount(address _vesting) public view returns(uint64, uint64, uint64, uint256) {
         require(_vesting != address(0), "Account can not be zero");
         require(vestingAccountAdded[_vesting], "Account not exists");
         
         Beneficiary memory beneficiary = vestingBeneficiary[_vesting];
         return (beneficiary.startTime, beneficiary.lockDuration, beneficiary.releaseDuration, beneficiary.released);
    }
    
    function _addVestingReleasedAmount(address _vesting, uint256 _amount) internal virtual {
         require(_vesting != address(0), "Account can not be zero");
         require(vestingAccountAdded[_vesting], "Account not exists");
         
         vestingBeneficiary[_vesting].released += _amount;
    }

    uint256[49] private __gap;
        
}