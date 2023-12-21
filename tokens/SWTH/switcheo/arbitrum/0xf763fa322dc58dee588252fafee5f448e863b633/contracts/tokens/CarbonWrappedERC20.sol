// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
* @title CarbonWrappedERC20 - Carbon Wrapped ERC20 Token
*
* @dev Standard ERC20 that mints / burns when unlock / lock with PoS
* LockProxy contract.
* @dev NOTE ERC20 sets token decimals to 18 by default. Update it by
* overriding the {decimals} function. It should be the same number as
* the decimals on source chain.
* 
* https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
*/
abstract contract CarbonWrappedERC20 is ERC20, Ownable {
  using SafeMath for uint256;

  /**
    * @dev address of the LockProxy contract.
    */
  address public lockProxyAddress;

  constructor(address _lockProxyAddress, string memory _name, string memory _symbol) 
  ERC20(_name, _symbol)
  {
    lockProxyAddress = _lockProxyAddress;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal override {
    if (sender == lockProxyAddress) {
      require(recipient != lockProxyAddress, "CarbonWrappedERC20: lockProxy should not call transfer to self");
      // lockProxy is the primary minter - so mint if required.
      uint256 balance = balanceOf(lockProxyAddress);
      if (balance < amount) {
        _mint(lockProxyAddress, amount.sub(balance));
      }
    }

    super._transfer(sender, recipient, amount);
  }

  /**
    * @dev Returns the total supply of tokens less amount locked on the
    * LockProxy contract.
    *
    * Tokens locked on the LockProxy contract are bridged to another
    * blockchain and are considered burnt on this blockchain. Although
    * tokens can be minted again when asset is bridged back to this
    * blockchain.
    *
    */
  function circulatingSupply() external view returns (uint256 amount) {
    return totalSupply().sub(balanceOf(lockProxyAddress));
  }

  /**
    * @dev Burns all tokens owned by the LockProxy contract.
    *
    * This function ensures the result of this.totalSupply() function
    * tallies with actual circulating supply within the blockchain.
    *
    * Actual total/circulating supply of the asset may be higher if
    * bridged token supply on other blockchains are taken in to
    * account.
    *
    */
  function burnLocked() public onlyOwner {
    uint256 balance = balanceOf(lockProxyAddress);
    if (balance > 0) {
      _burn(lockProxyAddress, balance);
    }
  }
}
