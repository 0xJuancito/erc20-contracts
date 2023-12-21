// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import '@openzeppelin/contracts/access/Ownable.sol';
import './CustomERC20.sol';

contract GOB is CustomERC20, Ownable  {

    bool stakingContractSet;

    constructor(        
        string memory name,
        string memory symbol,
        address receiver,
        uint256 totalSupply
    ) CustomERC20(name, symbol)  {

        _mint(receiver, totalSupply);
    }    

    function setStakingContract(address stakingContract_) external onlyOwner {
        require(!stakingContractSet, "already done");

        stakingContractSet = true;
        _stakingContract = stakingContract_;
    } 

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }    
}