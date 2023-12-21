// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// website: https://concentric.fi
// twitter: https://twitter.com/ConcentricFi
// discord: https://discord.gg/ConcentricFi

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CONE is ERC20("CONE", "CONE"), Ownable {
  using SafeMath for uint256;

  address public stakingContract;
  address public xCONE;

  constructor() {
    stakingContract = msg.sender;
    _mint(msg.sender, 265000e18);
  }

  function burn(address _from, uint256 _amount) external {
    require(msg.sender == xCONE);
    _burn(_from, _amount);
  }

  function burn(uint256 _amount) external {
    _burn(msg.sender, _amount);
  }

  function mint(address recipient, uint256 _amount) external {
    require(msg.sender == stakingContract || msg.sender == xCONE);
    _mint(recipient, _amount);
  }

  function updateMinters(address _xCONE, address _staking) external onlyOwner {
    xCONE = _xCONE;
    stakingContract = _staking;
  }
}
