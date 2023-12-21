// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "../interface/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TAFInvoice is Ownable{

    address public paid_by;
    IERC20 immutable public tafToken;
    uint256 immutable public amount;
    uint256 immutable public order_id;

    constructor(uint256 _order_id, uint256 _amount, address _token) {
        amount = _amount;
        order_id = _order_id;
        tafToken = IERC20(_token);
    }

    function withdrawToken(address reciever) public onlyOwner{
        tafToken.transfer(reciever, invoiceBalance());
    }

    function pay() public {
        require(tafToken.transferFrom(msg.sender, owner(), amount));
    }

    function invoiceBalance() public view returns (uint256) {
        return tafToken.balanceOf(address(this));
    }
}