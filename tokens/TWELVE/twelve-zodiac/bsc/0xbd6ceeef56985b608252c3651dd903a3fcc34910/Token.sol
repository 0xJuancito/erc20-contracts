// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "./ERC20.sol";
import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";

contract TwelveZodiac is ERC20, Ownable {
    using SafeERC20 for IERC20;
    
    uint256 maxSupply;
    uint256 initSupply;
    uint256 poolSupply;

    uint8 _decimals = 18;

    constructor() ERC20("Twelve Zodiac", "TWELVE") {
	    maxSupply = 21000000 * (10 ** _decimals);
        initSupply = (maxSupply * 8) / 100;
	    poolSupply = maxSupply - initSupply;

        _mint(msg.sender, initSupply);
	    _mint(msg.sender, poolSupply);
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);

    /**
    * Rescue Token
    */
    function recoveryToken(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function withdrawPayable() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}