// SPDX-License-Identifier: MIT LICENSE
/**
          |\___/|
          )     (
         =\     /=
           )===(
          /     \
         |       |
         |       |
         |       |
         |       |
          \     /
           `='='
 */
pragma solidity 0.8.15;
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

contract Rice is ERC20Burnable {
  constructor(address fundation) ERC20('RICE', 'RICE') {
    _mint(fundation, 20_000_000 ether);

    // 160_000_000(Barn) + 20_000_000(Team) = 180_000_000
    _mint(msg.sender, 180_000_000 ether);
  }
}
