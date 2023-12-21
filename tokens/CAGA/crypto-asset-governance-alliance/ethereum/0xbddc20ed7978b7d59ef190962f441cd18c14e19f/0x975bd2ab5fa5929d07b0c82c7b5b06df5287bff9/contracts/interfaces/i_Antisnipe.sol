// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IAntisnipe {
	function assureCanTransfer(address sender, address from, address to, uint256 amount) external;
}
