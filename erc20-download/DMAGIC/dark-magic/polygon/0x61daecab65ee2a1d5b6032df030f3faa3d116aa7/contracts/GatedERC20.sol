// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./openzeppelin/ERC20.sol";
import "./interfaces/IDarkMagicTransferGate.sol";
import "./openzeppelin/Owned.sol";
import "./libraries/SafeMath.sol";
import "./openzeppelin/TokensRecoverable.sol";
import "./interfaces/IGatedERC20.sol";


abstract contract GatedERC20 is ERC20, Owned, TokensRecoverable
{
    using SafeMath for uint256;

    IDarkMagicTransferGate public transferGate;
    mapping(address=>bool) IGNORED_ADDRESSES;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol)
    {

    }

    function setIgnoredAddresses(address _ignoredAddress, bool ignore)external ownerOnly{
        IGNORED_ADDRESSES[_ignoredAddress]=ignore;
    }

    function setIgnoredAddressBulk(address[] memory _ignoredAddressBulk, bool ignore)external ownerOnly{
        
        for(uint i=0;i<_ignoredAddressBulk.length;i++){
            address _ignoredAddress = _ignoredAddressBulk[i];
            IGNORED_ADDRESSES[_ignoredAddress] = ignore;
        }
    }
    
    function setTransferGate(IDarkMagicTransferGate _transferGate) public ownerOnly()
    {
        transferGate = _transferGate;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override 
    {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        IDarkMagicTransferGate _transferGate = transferGate;
        uint256 remaining = amount;
        _balanceOf[sender] = _balanceOf[sender].sub(amount, "ERC20: transfer amount exceeds balance");

        if(IGNORED_ADDRESSES[recipient]) {} // don't apply fees
        else
        {
            if (address(_transferGate) != address(0)) {
                (uint256 burn, TransferGateTarget[] memory targets) = _transferGate.handleTransfer(msg.sender, sender, recipient, amount);            
                if (burn > 0) {
                    remaining = remaining.sub(burn, "Burn too much");
                    totalSupply = totalSupply.sub(burn);
                    emit Transfer(sender, address(0), burn);
                }
                for (uint256 x = 0; x < targets.length; ++x) {
                    (address dest, uint256 amt) = (targets[x].destination, targets[x].amount);
                    remaining = remaining.sub(amt, "Transfer too much");
                    _balanceOf[dest] = _balanceOf[dest].add(amt);
                    emit Transfer(sender, dest, amt);
                }
            }
        }
        _balanceOf[recipient] = _balanceOf[recipient].add(remaining);
        emit Transfer(sender, recipient, remaining);
    }
}
