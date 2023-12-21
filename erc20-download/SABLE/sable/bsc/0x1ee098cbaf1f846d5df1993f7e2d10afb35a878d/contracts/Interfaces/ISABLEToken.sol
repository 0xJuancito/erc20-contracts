// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";
import "../Dependencies/IERC2612.sol";

interface ISABLEToken is IERC20, IERC2612 { 
   
    // --- Events ---
    
    event CommunityIssuanceAddressSet(address _communityIssuanceAddress);
    event SABLEStakingAddressSet(address _sableStakingAddress);

    // --- Functions ---
    
    function getDeploymentStartTime() external view returns (uint256);

}
