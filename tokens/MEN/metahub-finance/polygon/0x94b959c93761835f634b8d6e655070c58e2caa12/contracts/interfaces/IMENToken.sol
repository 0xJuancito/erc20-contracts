// SPDX-License-Identifier: BSD 3-Clause

pragma solidity 0.8.9;

import "../libs/zeppelin/token/BEP20/IBEP20.sol";

interface IMENToken is IBEP20 {
  enum TaxType {
    Buy,
    Sell,
    Transfer,
    Claim
  }
  function releaseMintingAllocation(uint _amount) external returns (bool);
  function releaseCLSAllocation(uint _amount) external returns (bool);
  function burn(uint _amount) external;
  function mint(uint _amount) external returns (bool);
  function lsdDiscountTaxPercentages(TaxType _type) external returns (uint);
  function getWhitelistTax(address _to, TaxType _type) external returns (uint, bool);
}
