// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVTOKEN {
    /*----------  FUNCTIONS  --------------------------------------------*/
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function OTOKEN() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function balanceOfTOKEN(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalSupplyTOKEN() external view returns (uint256);
}