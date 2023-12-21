// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./NovaXERC20.sol";
import "./NovaXERC20Burnable.sol";

contract NovaXToken is NovaXERC20, NovaXERC20Burnable {
    constructor(
        address taxAddress_,
        uint16 taxBuyFee_
    ) NovaXERC20("NovaX", "NOVAX", taxAddress_, taxBuyFee_) {
        _mint(msg.sender, 15_000_000 * 10 ** decimals());
    }

    /**
     * @dev Recover lost bnb and send it to the contract owner
     */
    function recoverLostBNB() public onlyOwner {
        address payable recipient = payable(msg.sender);
        recipient.transfer(address(this).balance);
    }

    /**
     * @dev withdraw some token balance from contract to owner account
     */
    function withdrawTokenEmergency(address _token, uint256 _amount) public onlyOwner {
        require(_amount > 0, "NOVAX_TOKEN: INVALID AMOUNT");
        require(IERC20(_token).transfer(msg.sender, _amount), "NOVAX_TOKEN: CANNOT WITHDRAW TOKEN");
    }
}
