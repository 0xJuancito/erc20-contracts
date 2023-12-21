// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

import "./_TokenGroups.sol";
import "./__Erc20.sol";

abstract contract Token is Erc20, TokenGroups {

    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowed;
    uint256 internal totalTokenSupply;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public unlockTime;

    event SetNewUnlockTime(uint256 unlockTime);

    /**
     * @dev Allow only when the contract is unlocked, or if the sender is an admin, an attorney, or whitelisted.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    modifier whenUnlocked() {
        expect(
            block.timestamp > unlockTime || isAdmin(msg.sender) || isAttorney(msg.sender) || isWhitelisted(msg.sender),
            ERROR_TOKEN_LOCKED
        );
        _;
    }

    /**
     * @dev Lock the contract if not already locked until the given time.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function setUnlockTime(uint256 timestamp) public onlyAdminOrAttorney {
        unlockTime = timestamp;
        emit SetNewUnlockTime(unlockTime);
    }

    /**
     * @dev Total number of tokens.
     */
    function totalSupply() public view override returns (uint256) {
        return totalTokenSupply;
    }

    /**
     * @dev Get account balance.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    /**
     * @dev Get allowance for an owner-spender pair.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowed[owner][spender];
    }

    /**
     * @dev Transfer tokens.
     */
    function transfer(address to, uint256 value) public override whenNotPaused whenUnlocked returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Base method for transferring tokens.
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        expect(to != address(0), ERROR_INVALID_ADDRESS);
        expect(!isFrozen(from), ERROR_FROZEN);
        expect(!isFrozen(to), ERROR_FROZEN);

        balances[from] -= value;
        balances[to] += value;
        emit Transfer(from, to, value);
    }


    /**
     * @dev Approve a spender to transfer the given amount of the sender's tokens.
     */
    function approve(address spender, uint256 value)
    public
    override
    isNotFrozen
    whenNotPaused
    whenUnlocked
    returns (bool)
    {
        expect(spender != address(0), ERROR_INVALID_ADDRESS);

        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens a spender can transfer from the sender's account.
     */
    function increaseAllowance(address spender, uint256 addedValue)
    public
    isNotFrozen
    whenNotPaused
    whenUnlocked
    returns (bool)
    {
        expect(spender != address(0), ERROR_INVALID_ADDRESS);

        allowed[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens a spender can transfer from the sender's account.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    isNotFrozen
    whenNotPaused
    whenUnlocked
    returns (bool)
    {
        expect(spender != address(0), ERROR_INVALID_ADDRESS);

        allowed[msg.sender][spender] -= subtractedValue;
        emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Transfer tokens from an account the sender has been approved to send from.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override whenNotPaused whenUnlocked returns (bool) {
        allowed[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }


}
