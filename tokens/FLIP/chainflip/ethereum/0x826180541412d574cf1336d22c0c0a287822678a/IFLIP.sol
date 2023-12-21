// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC20.sol";

/**
 * @title    FLIP interface for the FLIP utility token
 */
interface IFLIP is IERC20 {
    event IssuerUpdated(address oldIssuer, address newIssuer);

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  State-changing functions                //
    //                                                          //
    //////////////////////////////////////////////////////////////

    function mint(address account, uint amount) external;

    function burn(address account, uint amount) external;

    function updateIssuer(address newIssuer) external;

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  Non-state-changing functions            //
    //                                                          //
    //////////////////////////////////////////////////////////////

    function getIssuer() external view returns (address);
}
