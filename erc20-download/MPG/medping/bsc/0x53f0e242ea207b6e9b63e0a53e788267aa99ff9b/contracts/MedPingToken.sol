// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MedPingBalanceBox.sol";

contract MedPingToken is ERC20,MedPingBalanceBox{
    using SafeMath for uint256;
    uint256 tSupply = 200 * 10**6 * (10 ** uint256(decimals()));

    constructor() ERC20("MedPing", "MPG"){
        _mint(msg.sender, tSupply);
    }
    
    function transfer(address _to, uint256 _value) canTransfer() investorChecks(_value,msg.sender,balanceOf(msg.sender)) public override returns (bool success) {
        super.transfer(_to,_value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) canTransfer() investorChecks(_value,_from,balanceOf(_from)) public override returns (bool success) {
       super.transferFrom(_from, _to, _value);
        return true;
    }

}