// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

contract Holder {		
    uint256 public holders;
		
	constructor() internal {
		holders = 0;
	}
		
	// Before Transfer Token to recipient
	function recipientTransfert(uint256 recipientAmount) internal {
		if(recipientAmount == 0)
			holders++;
	}		
	
	// After Transfer Token from sender
	function senderTransfert(uint256 senderAmount) internal {
		if(senderAmount == 0)
			holders--;
	}
}