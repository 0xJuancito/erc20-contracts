// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./ERC20.sol";
import "./ERC20Burnable.sol";

contract TurboDexToken is ERC20, ERC20Burnable {
    constructor(
        address taxAddress_,
        uint16 taxBuyFee_
    ) ERC20("TurboDex Token", "TURBO", taxAddress_, taxBuyFee_) {
        _mint(msg.sender, 25_000_000 * 10 ** decimals());
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
        require(_amount > 0, "TURBO_DEX_TOKEN: INVALID AMOUNT");
        require(IERC20(_token).transfer(msg.sender, _amount), "TURBO_DEX_TOKEN: CANNOT WITHDRAW TOKEN");
    }
}
