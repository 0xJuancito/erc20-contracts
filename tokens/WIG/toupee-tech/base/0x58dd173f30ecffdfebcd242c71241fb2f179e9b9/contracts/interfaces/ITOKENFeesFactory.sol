// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ITOKENFeesFactory {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function createTokenFees(address _rewarder, address _TOKEN, address _BASE, address _OTOKEN) external returns (address);
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
}
