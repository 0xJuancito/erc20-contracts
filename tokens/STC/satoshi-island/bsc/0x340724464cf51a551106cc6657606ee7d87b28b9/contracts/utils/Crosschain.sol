// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';

abstract contract Crosschain is ERC20, ERC20Burnable, AccessControlEnumerable {
    event MinterAdded(address indexed);

    bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');
    uint24 private constant DELAY = 48 hours;
    mapping(address => uint256) public minterSince;

    function _grantRole(bytes32 role, address account) internal virtual override {
        if (role == MINTER_ROLE) {
            minterSince[account] = block.timestamp;
            emit MinterAdded(account);
        }
        super._grantRole(role, account);
    }

    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        if (role == MINTER_ROLE && minterSince[account] + DELAY > block.timestamp) {
            return false;
        }
        return super.hasRole(role, account);
    }

    function bridgeBurn(address owner, uint256 amount) public onlyRole(MINTER_ROLE) {
        _burn(owner, amount);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
