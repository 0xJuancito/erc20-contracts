# @version 0.3.10

"""
@title yPRISMA
@license GNU AGPLv3
@author Yearn Finance
"""

from vyper.interfaces import ERC20

implements: ERC20

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

event DelegateMint:
    minter: indexed(address)
    recipient: indexed(address)
    amount: uint256

event ApproveMinter:
    minter: indexed(address)
    approved: indexed(bool)

event UpdateOperator:
    operator: indexed(address)

ylocker: public(immutable(address))
prisma: public(immutable(address))
name: public(immutable(String[32]))
symbol: public(immutable(String[32]))
decimals: public(immutable(uint8))

balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
totalSupply: public(uint256)
approved_minters: public(HashMap[address, bool])
operator: public(address)
proposed_operator: public(address)

@external
def __init__(_name: String[32], _symbol: String[32], _prisma: address, _ylocker: address, _operator: address):
    name = _name
    symbol = _symbol
    decimals = 18
    prisma = _prisma
    ylocker = _ylocker
    self.operator = _operator

@external
def transfer(_to : address, _value : uint256) -> bool:
    """
    @dev Transfer token for a specified address
    @param _to The address to transfer to.
    @param _value The amount to be transferred.
    """
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value
    log Transfer(msg.sender, _to, _value)
    return True


@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    """
     @dev Transfer tokens from one address to another.
     @param _from address The address which you want to send tokens from
     @param _to address The address which you want to transfer to
     @param _value uint256 the amount of tokens to be transferred
    """
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    self.allowance[_from][msg.sender] -= _value
    log Transfer(_from, _to, _value)
    return True


@external
def approve(_spender : address, _value : uint256) -> bool:
    """
    @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    @param _spender The address which will spend the funds.
    @param _value The amount of tokens to be spent.
    """
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True
        
@internal
def _mint(_to: address, _value: uint256):
    self.totalSupply += _value
    self.balanceOf[_to] += _value
    log Transfer(empty(address), _to, _value)

@external
def mint(_amount: uint256 = max_value(uint256), _recipient: address = msg.sender) -> uint256:
    """
    @notice Lock any amount of the underlying token to mint yTOKEN 1 to 1.
    @param _amount The desired amount of tokens to lock / yTOKENs to mint.
    @param _recipient The address which minted yTOKENS should be received at.
    """
    assert _recipient not in [self, empty(address)]
    amount: uint256 = _amount
    if amount == max_value(uint256):
        amount = ERC20(prisma).balanceOf(msg.sender)
    assert amount > 0
    assert ERC20(prisma).transferFrom(msg.sender, ylocker, amount)
    self._mint(_recipient, amount)
    return amount

@external
def delegate_mint(_recipient: address, _amount: uint256) -> uint256:
    """
    @dev Minters must be permitted to mint upon user claims from the vault.
    @param _amount The desired amount of tokens to lock / yTOKENs to mint.
    @param _recipient The address which minted yTOKENS should be received at.
    """
    assert self.approved_minters[msg.sender], "!approved"
    self._mint(_recipient, _amount)
    log DelegateMint(msg.sender, _recipient, _amount)
    return _amount

@external
def approve_minter(_minter: address, _approved: bool):
    assert msg.sender == self.operator, "!approved"
    self.approved_minters[_minter] = _approved
    log ApproveMinter(_minter, _approved)

@external
def set_operator(_proposed_operator: address):
    assert msg.sender == self.operator
    self.proposed_operator = _proposed_operator

@external
def accept_operator():
    proposed_operator: address = self.proposed_operator
    assert msg.sender == proposed_operator
    self.operator = proposed_operator
    self.proposed_operator = empty(address)
    log UpdateOperator(proposed_operator)

@external
def sweep(_token: address, _amount: uint256 = max_value(uint256)):
    operator: address = self.operator
    assert msg.sender == operator
    amount: uint256 = _amount
    if amount == max_value(uint256):
        amount = ERC20(_token).balanceOf(self)
    assert amount > 0
    assert ERC20(_token).transfer(operator, amount, default_return_value=True)