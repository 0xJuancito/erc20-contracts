// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/BaseOFTV2.sol";

abstract contract OFTV2Upgradeable is Ownable2Step, ERC20Upgradeable, BaseOFTV2 {
    uint internal immutable ld2sdRate;

    constructor(uint8 _sharedDecimals, address _lzEndpoint) BaseOFTV2(_sharedDecimals, _lzEndpoint) {
        uint8 _decimals = decimals();
        require(_sharedDecimals <= _decimals, "OFT: sharedDecimals must be <= decimals");
        ld2sdRate = 10 ** (_decimals - _sharedDecimals);
    }

    function __OFTV2Upgradeable_init(string memory _name, string memory _symbol) internal onlyInitializing {
        _transferOwnership(_msgSender());
        __ERC20_init(_name, _symbol);
        __OFTV2Upgradeable_init_unchained();
    }

    function __OFTV2Upgradeable_init_unchained() internal onlyInitializing {}

    /************************************************************************
     * public functions
     ************************************************************************/
    function circulatingSupply() public view virtual override returns (uint) {
        return totalSupply();
    }

    function token() public view virtual override returns (address) {
        return address(this);
    }

    /************************************************************************
     * internal functions
     ************************************************************************/
    function _debitFrom(address _from, uint16, bytes32, uint _amount) internal virtual override returns (uint) {
        address _spender = _msgSender();
        if (_from != _spender) _spendAllowance(_from, _spender, _amount);
        _burn(_from, _amount);
        return _amount;
    }

    function _creditTo(uint16, address _toAddress, uint _amount) internal virtual override returns (uint) {
        _mint(_toAddress, _amount);
        return _amount;
    }

    function _transferFrom(address _from, address _to, uint _amount) internal virtual override returns (uint) {
        address _spender = _msgSender();
        // if transfer from this contract, no need to check allowance
        if (_from != address(this) && _from != _spender) _spendAllowance(_from, _spender, _amount);
        _transfer(_from, _to, _amount);
        return _amount;
    }

    function _ld2sdRate() internal view virtual override returns (uint) {
        return ld2sdRate;
    }

    function _transferOwnership(address _newOwner) internal virtual override(Ownable, Ownable2Step) {
        Ownable2Step._transferOwnership(_newOwner);
    }

    function transferOwnership(address _newOwner) public virtual override(Ownable, Ownable2Step) {
        Ownable2Step.transferOwnership(_newOwner);
    }

    function _msgSender() internal view virtual override(Context, ContextUpgradeable) returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual override(Context, ContextUpgradeable) returns (bytes calldata) {
        return msg.data;
    }
}
