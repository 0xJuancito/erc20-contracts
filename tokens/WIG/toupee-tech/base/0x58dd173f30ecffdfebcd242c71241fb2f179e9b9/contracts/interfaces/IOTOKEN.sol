// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IOTOKEN {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function burnFrom(address account, uint256 amount) external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function mint(address account, uint amount) external returns (bool);
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function minter() external view returns (address);
}