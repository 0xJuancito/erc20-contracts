// SPDX-License-Identifier: BSD 3-Clause

pragma solidity 0.8.9;

interface ILSD {
  function isQualifiedForTaxDiscount(address _user) external view returns (bool);
  function transfer(address _from, address _to, uint _stAmount) external;
  function mint(uint _tokenAmount, uint _duration) external;
  function burn(uint _stAmount) external;
}
