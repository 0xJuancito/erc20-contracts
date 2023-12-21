// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './token/oft/OFT.sol';

contract ZooDAO is OFT {
	constructor(address _lzEndpoint) OFT('ZooDAO', 'ZOO', _lzEndpoint) {}
}
