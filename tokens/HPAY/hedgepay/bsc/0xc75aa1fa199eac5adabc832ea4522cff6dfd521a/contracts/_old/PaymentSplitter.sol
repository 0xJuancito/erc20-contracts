// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IFundProcessor.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PaymentSplitter is IFundProcessor, Ownable {
    using SafeERC20 for IERC20;
    address[3] addresses;

    constructor(
        address _addr1,
        address _addr2,
        address _addr3
    ) {
        addresses[0] = _addr1;
        addresses[1] = _addr2;
        addresses[2] = _addr3;
    }

    function processFunds(IERC20 token, uint256 amount) override external {
        token.safeTransferFrom(msg.sender, address(this), amount);     
        distribute(token);
    }

    function distribute(IERC20 token) public {
        uint256 splitAmount = token.balanceOf(address(this)) / 3;
        if (
            splitAmount == 0 ||
            addresses[0] == address(0) ||
            addresses[1] == address(0) ||
            addresses[2] == address(0)
        ) {
            return;
        }
        if (splitAmount > 0) {
            token.safeTransfer(addresses[0], splitAmount);
            token.safeTransfer(addresses[1], splitAmount);
            token.safeTransfer(addresses[2], token.balanceOf(address(this)));
        }
    }

    function setAddress(uint256 index, address newAddress) external onlyOwner  {
        require(address(0) != newAddress, "Address cannot be 0");
        addresses[index] = newAddress;
    }

    function getAddress(uint256 index) external view onlyOwner returns(address)  {
        return addresses[index];
    }

    function saveTokens(IERC20 token, address destination) external onlyOwner {
        token.safeTransfer(destination, token.balanceOf(address(this)));
    }
}
