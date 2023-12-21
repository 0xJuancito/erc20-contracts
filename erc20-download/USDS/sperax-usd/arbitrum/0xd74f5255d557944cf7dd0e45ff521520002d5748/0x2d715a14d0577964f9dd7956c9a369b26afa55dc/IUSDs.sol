// Current version: 1
// This contract's version: 2
// Changes: removed rebase's impact on USDs outflow

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IUSDs {
    function mint(address _account, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
    function burnExclFromOutFlow(address _account, uint256 _amount) external;
    function changeSupply(uint256 _newTotalSupply) external;
    function mintedViaUsers() external view returns (uint256);
    function burntViaUsers() external view returns (uint256);
}
