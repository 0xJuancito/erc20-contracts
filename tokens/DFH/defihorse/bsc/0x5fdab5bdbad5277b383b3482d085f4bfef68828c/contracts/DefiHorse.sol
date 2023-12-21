// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DefiHorse is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, Pausable {
    uint256 public _taxFee = 1;
    address _taxAddress = 0x93A364BcA26F754DaBF95fC5Ac3cb62196b65590;
    constructor() ERC20("DefiHorse", "DFH") {
        _mint(msg.sender, 668000000 * 10 ** decimals());
    
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    

    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
          _taxFee = taxFee;
      }

    function setTaxAddress(address taxAddress) external onlyOwner {
          _taxAddress = taxAddress;
      }

    function TaxAddress() external view returns (address){
            return _taxAddress;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    )
        internal
        virtual
        override(ERC20)
        whenNotPaused
    {
      
       {
            // default tax is 1% of every transfer
            uint256 taxAmount = (amount*_taxFee)/100;
            

            // default 99% of transfer sent to recipient
            uint256 sendAmount = amount-(taxAmount);
            

          
            super._transfer(sender, _taxAddress, taxAmount);
            super._transfer(sender, recipient, sendAmount);
            amount = sendAmount;
        }
    }

}
