// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IOTOKENFactory {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function createOToken(address _owner) external returns (address);
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
}