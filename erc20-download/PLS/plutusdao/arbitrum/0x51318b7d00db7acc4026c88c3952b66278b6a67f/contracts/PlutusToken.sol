// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// private tge: 4_200_000
// team alloc: 12_000_000
// public tge: 10_000_000
// bonding: 10_000_000
// ops: 13_800_000
// liq mining: 15_000_000
// platform rewards: 35_000_000

contract PlutusToken is ERC20 {
  address public operator;
  uint256 public constant FIXED_SUPPLY = 100_000_000 * 1e18;

  constructor() ERC20('Plutus', 'PLS') {
    operator = msg.sender;
  }

  function setOperator(address _operator) external {
    require(msg.sender == operator, 'Unauthorized');

    operator = _operator;
  }

  function mint(address _to, uint256 _amount) external {
    require(_amount + totalSupply() <= FIXED_SUPPLY, 'Supply Cap reached');
    require(msg.sender == operator, 'Unauthorized');

    _mint(_to, _amount);
  }

  function burn(address _from, uint256 _amount) external {
    require(msg.sender == operator, 'Unauthorized');

    _burn(_from, _amount);
  }
}
