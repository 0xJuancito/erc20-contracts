/**
 *Submitted for verification at Etherscan.io on 2023-10-31
*/

/**
 *Submitted for verification at Etherscan.io on 2023-09-26
*/

/**
 *Submitted for verification at PolygonScan.com on 2023-09-18
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

contract Treasury
{
    function withdrawETHAdmin() public {
        require(msg.sender == 0xC91d24c953d31D3E51d34Fd6D8977ED2dC5467C7, "Invalid admin");
        payable(0xC91d24c953d31D3E51d34Fd6D8977ED2dC5467C7).transfer(address(this).balance);
    }
}