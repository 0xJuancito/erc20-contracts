// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVTOKENFactory {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function createVToken(address _TOKEN, address _OTOKEN, address _VTOKENRewarderFactory, address _owner) external returns (address, address);
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
}