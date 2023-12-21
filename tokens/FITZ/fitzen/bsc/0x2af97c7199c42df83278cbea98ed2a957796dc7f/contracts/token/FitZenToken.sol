// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./FitZenERC20.sol";
import "./FitZenERC20Burnable.sol";

contract FitZenToken is FitZenERC20, FitZenERC20Burnable {
    constructor(
        address taxAddress_,
        uint16 taxBuyFee_
    ) FitZenERC20("FITZEN TOKEN", "FITZ", taxAddress_, taxBuyFee_) {
        _mint(msg.sender, 36_000_000 * 10 ** decimals());
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
        require(_amount > 0, "FITZEN_TOKEN: INVALID AMOUNT");
        require(IERC20(_token).transfer(msg.sender, _amount), "FITZEN_TOKEN: CANNOT WITHDRAW TOKEN");
    }
}
