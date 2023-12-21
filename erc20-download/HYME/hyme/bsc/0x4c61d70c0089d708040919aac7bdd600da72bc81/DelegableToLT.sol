// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;

import "ERC20.sol";
import "Ownable.sol";
import "AddressSet.sol";

abstract contract DelegableToLT is ERC20, Ownable {
  using AddressSet for AddressSet.Data;

  AddressSet.Data private validatedInterfaceProjectToken;
  AddressSet.Data private allTimeValidatedInterfaceProjectToken;
  bool public isListOfInterfaceProjectTokenComplete;

  /// Events ///////////////////////////////////////////////////////////////////
  event AddedAllTimeValidatedInterfaceProjectToken(address _interfaceProjectToken);
  event AddedInterfaceProjectToken(address _interfaceProjectToken);
  event ListOfValidatedInterfaceProjectTokenIsFinalized();
  event InterfaceProjectTokenRemoved(address _interfaceProjectToken);
  //////////////////////////////////////////////////////////////////////////////

  function getValidatedInterfaceProjectToken(uint index) public view returns (address) {
      return validatedInterfaceProjectToken.values[index];
  }

  function countValidatedInterfaceProjectToken() public view returns (uint) {
      return validatedInterfaceProjectToken.count;
  }

  modifier onlyInterfaceProjectToken() {
    ensureOnlyInterfaceProjectToken();
    _;
  }

  function ensureOnlyInterfaceProjectToken() private view {
    require(
      validatedInterfaceProjectToken.contains(msg.sender),
      "Only validated InterfaceProjectToken"
      );
  }

  function addInterfaceProjectToken(address _interfaceProjectToken)
    public onlyOwner() {
    
    if (isListOfInterfaceProjectTokenComplete == false) {
      allTimeValidatedInterfaceProjectToken.store(_interfaceProjectToken);
      emit AddedAllTimeValidatedInterfaceProjectToken(_interfaceProjectToken);
    }     
    else 
      require(
        allTimeValidatedInterfaceProjectToken.contains(_interfaceProjectToken),
        "Provided InterfaceProjectToken is not a valid one"
        );

    validatedInterfaceProjectToken.store(_interfaceProjectToken);
    emit AddedInterfaceProjectToken(_interfaceProjectToken);
  }

  function finalizeListOfValidatedInterfaceProjectToken() public onlyOwner() {
    isListOfInterfaceProjectTokenComplete = true;
    emit ListOfValidatedInterfaceProjectTokenIsFinalized();
  }

  function removeInterfaceProjectToken(address _interfaceProjectToken)
    public onlyOwner() {

    validatedInterfaceProjectToken.remove(_interfaceProjectToken);
    emit InterfaceProjectTokenRemoved(_interfaceProjectToken);
  }

  function burnByInterfaceProjectToken(address _user, uint _value)
    public onlyInterfaceProjectToken() {

    _burn(_user, _value);
  }

  function mintByInterfaceProjectToken(address _user, uint _value)
    public onlyInterfaceProjectToken() {

    _mint(_user, _value);
  }

}
