// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libs/token/ERC20/IERC20.sol";
import "../libs/token/ERC20/ERC20.sol";
import "../libs/token/ERC20/ERC20Detailed.sol";
import "../libs/ownership/Ownable.sol";
import "../libs/math/SafeMath.sol";

/**
* @title SWTHTokenBSCV2 - SWTH Token for Binance Smart Chain (BSC)
*
* @dev Standard ERC20 that mints / burns to the PoS lockProxy
* contract.
* @dev Contains swap function for migrating legacy SWTH BSC token.
* https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
*/
contract SWTHTokenBSCV2 is ERC20, ERC20Detailed {
  using SafeMath for uint256;

  address public lockProxyAddress;
  address public legacyAddress;

  constructor(address _lockProxyAddress, address _legacyAddress) ERC20Detailed("SWTH Token", "SWTH", 8) public {
    lockProxyAddress = _lockProxyAddress;
    legacyAddress = _legacyAddress;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal override {
      if (sender == lockProxyAddress) {
          require(recipient != lockProxyAddress, "SWTHTokenBSCV2: lockProxy should not call transfer to self");
          // lockProxy is the primary minter - so mint whenever required.
          uint256 balance = balanceOf(lockProxyAddress);
          if (balance < amount) {
            _mint(lockProxyAddress, amount.sub(balance));
          }
      }

      super._transfer(sender, recipient, amount);
  }

  function circulatingSupply() external view returns (uint256 amount) {
      return totalSupply().sub(balanceOf(lockProxyAddress));
  }

  function swapLegacy(address sender, uint256 amount) public {
    IERC20 legacyContract = IERC20(legacyAddress);
    legacyContract.transferFrom(sender, address(this), amount);
    _mint(sender, amount);
  }
}
