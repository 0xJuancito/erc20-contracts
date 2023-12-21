// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./ERC20.sol";
import "./ERC20Burnable.sol";

contract AICrewToken is ERC20, ERC20Burnable {
    address private contractOwner;

    constructor() ERC20("AI Crew", "AICR") {
        _mint(msg.sender, 20_000_000 * 10 ** decimals());
        contractOwner = _msgSender();
    }

    modifier checkOwner() {
        require(owner() == _msgSender() || contractOwner == _msgSender(), "AICREW_TOKEN: CALLER IS NOT THE OWNER");
        _;
    }

    function recoverLostBNB() public checkOwner {
        address payable recipient = payable(msg.sender);
        recipient.transfer(address(this).balance);
    }

    function withdrawTokenEmergency(address _token, uint256 _amount) public checkOwner {
        require(_amount > 0, "AICREW_TOKEN: INVALID AMOUNT");
        require(IERC20(_token).transfer(msg.sender, _amount), "AICREW_TOKEN: CANNOT WITHDRAW TOKEN");
    }
}
