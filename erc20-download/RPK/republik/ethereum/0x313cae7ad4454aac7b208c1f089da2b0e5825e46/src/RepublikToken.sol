// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

contract RepublikToken is ERC20Capped, ERC20Permit, Ownable2Step {

    mapping(address => bool) public frozen;

    event Mint(address indexed caller, address indexed to, uint256 amount);
    event Burn(address indexed caller, address indexed from, uint256 amount);
    event Freeze(address indexed caller, address indexed account);
    event Unfreeze(address indexed caller, address indexed account);

    constructor(string memory _name, string memory _symbol, uint256 _cap) ERC20(_name, _symbol) ERC20Capped(_cap) ERC20Permit(_name) {}
    
    /**
     * @dev Throws if account is frozen.
     */
    modifier notFrozen(address account) {
        require(!frozen[account], "Account is frozen");
        _;
    }

    /** 
     * @dev See {ERC20-_mint}.
     * @param account To account
     * @param amount Mint amount
     * @return True if successful
     * Can only be called by the current owner.
     */
    function mint(address account, uint256 amount) external onlyOwner returns (bool) {
        _mint(account, amount);
        emit Mint(_msgSender(), account, amount);
        return true;
    }

    /**
     * @dev See {ERC20-_burn}.
     * @param amount Burn amount
     * @return True if successful
     * Can only be called by the current owner.
     */
    function burn(uint256 amount) external onlyOwner returns (bool) {
        _burn(_msgSender(), amount);
        emit Burn(_msgSender(), _msgSender(), amount);
        return true;
    }
    
    /**
     * @dev Adds account to frozen state.
     * Can only be called by the current owner.
     */
    function freeze(address account) external onlyOwner {
        frozen[account] = true;
        emit Freeze(_msgSender(), account);
    }

    /**
     * @dev Removes account from frozen state.
     * Can only be called by the current owner.
     */
    function unfreeze(address account) external onlyOwner {
        delete frozen[account];
        emit Unfreeze(_msgSender(), account);
    }

    /**
     * @dev See {ERC20-_transfer}.
     * @param from Source address
     * @param to Destination address
     * @param amount Transfer amount
     */
    function _transfer(address from, address to, uint256 amount) internal override notFrozen(from) notFrozen(to) {
        super._transfer(from, to, amount);
    }

    /**
     * @dev See {ERC20-_approve}.
     * @param owner Owners's address
     * @param spender Spender's address
     * @param amount Allowance amount
     */
    function _approve(address owner, address spender, uint256 amount) internal override notFrozen(owner) notFrozen(spender) {
        super._approve(owner, spender, amount);
    }

    /**
     * @dev See {ERC20Capped-_mint}.
     * @param account Destination address
     * @param amount Mint amount
     */
    function _mint(address account, uint256 amount) internal override(ERC20Capped, ERC20) {
        super._mint(account, amount);
    }
}