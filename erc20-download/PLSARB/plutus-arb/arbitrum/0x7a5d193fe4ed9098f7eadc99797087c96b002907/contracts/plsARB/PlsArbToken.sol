// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';

contract PlsArbToken is ERC20, Ownable2Step, ERC20Permit {
  address public operator;

  constructor() ERC20('Plutus ARB', 'plsARB') ERC20Permit('Plutus ARB') {}

  function mint(address _to, uint256 _amount) external {
    if (msg.sender != operator) revert UNAUTHORIZED();
    _mint(_to, _amount);
  }

  function burn(address _from, uint256 _amount) external {
    if (msg.sender != operator) revert UNAUTHORIZED();
    _burn(_from, _amount);
  }

  /** OWNER FUNCTIONS */
  function setOperator(address _operator) external onlyOwner {
    operator = _operator;
  }

  error UNAUTHORIZED();
}
