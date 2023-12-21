pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "ERC20.sol";
import "Ownable.sol";
import "SafeMath.sol";

contract BananaToken is ERC20("Banana", "BANANA"), Ownable {
	using SafeMath for uint256;

	address public constant MINT_ADDRESS = 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa;
	address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

	modifier onlyMinter() {
		require(msg.sender == MINT_ADDRESS, "!minter");
		_;
	}

	function deposit(address user, bytes calldata depositData) external onlyMinter {
		uint256 amount = abi.decode(depositData, (uint256));
		_mint(user, amount);
	}

	function burn(uint256 _amount) external {
		_transfer(_msgSender(), BURN_ADDRESS, _amount);
	}

	function burnFrom(address _user, uint256 _amount) external {
		uint256 currentAllowance = allowance(_user, msg.sender);
		_approve(_user, msg.sender, currentAllowance.sub(_amount));
		transferFrom(_user, BURN_ADDRESS, _amount);
	}

	/**
	 * @notice called when user wants to withdraw tokens back to root chain
	 * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
	 * @param amount amount of tokens to withdraw
	 */
	function withdraw(uint256 amount) external {
		_burn(_msgSender(), amount);
	}
}