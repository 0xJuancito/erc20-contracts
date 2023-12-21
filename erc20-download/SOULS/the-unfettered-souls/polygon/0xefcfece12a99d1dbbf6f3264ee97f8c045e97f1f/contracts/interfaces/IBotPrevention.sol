// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IBotPrevention {
    function setDexPairAddress(address _pairAddress) external;

    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) external view  returns (bool);

    function afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) external  returns (bool);

	function resetBotPreventionData() external;
}
