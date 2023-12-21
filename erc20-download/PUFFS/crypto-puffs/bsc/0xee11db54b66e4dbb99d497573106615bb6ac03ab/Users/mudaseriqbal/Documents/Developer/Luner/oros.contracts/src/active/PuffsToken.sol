// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ITokenPresenter.sol";

contract PuffsToken is ERC20, Ownable {

  address public presenter;

  constructor() ERC20("Crypto Puffs", "PUFFS") {
    _mint(_msgSender(), 1000000000 * 10 ** uint256(decimals()));
    presenter = address(0);
  }

  /**
  * @dev set the decimal
  */
  function decimals() override public pure returns (uint8) {
    return 18;
  }

  /**
  * @dev set the presenter of the token to decide transfer functionality
  * @param _presenter address of presenter
  */
  function setPresenter(address _presenter) onlyOwner public {
    presenter = _presenter;
  }

  /**
  * @dev transfer the tokens, if presenter is not set, normal behaviour
  */
  function transfer(address recipient, uint256 amount) public override returns (bool) {
    // Transfer fund and responsibility to presenter
    if (presenter != address(0) && presenter != _msgSender()) {
      require(super.transfer(presenter, amount), "PuffsToken: transfer to presenter error");
      return ITokenPresenter(presenter).receiveTokens(_msgSender(), recipient, amount);
    } else {
      return super.transfer(recipient, amount);
    }
  }

  /**
  * @dev transfer the tokens from an address, if presenter is not set, normal behaviour
  */
  function transferFrom(address from, address recipient, uint256 amount) public override returns (bool) {
    // Transfer fund and responsibility to presenter
    if (presenter != address(0) && presenter != _msgSender()) {
      require(super.transferFrom(from, presenter, amount), "PuffsToken: transfer from to presenter error");
      return ITokenPresenter(presenter).receiveTokensFrom(_msgSender(), from, recipient, amount);
    } else {
      return super.transferFrom(from, recipient, amount);
    }
  }
}
