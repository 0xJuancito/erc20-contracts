// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./lz/contracts/token/oft/extension/GlobalCappedOFT.sol";

contract TigrisToken is GlobalCappedOFT {

    mapping(address => bool) public isMinter;

    modifier onlyMinter() {
        require(isMinter[_msgSender()], "!Minter");
        _;
    }

    constructor(string memory name_, string memory symbol_, address lzEndpoint_) GlobalCappedOFT(name_, symbol_, 2_000_000 ether, lzEndpoint_) {}

    function burn(
        address _account,
        uint256 _amount
    ) 
        external 
        onlyMinter
    {
        _burn(_account, _amount);
    }

    function mint(
        address _account,
        uint256 _amount
    ) 
        external
        onlyMinter
    {  
        _mint(_account, _amount);
    }

    function setMinter(
        address _address,
        bool _status
    ) 
        external
        onlyOwner
    {
        isMinter[_address] = _status;
    }

    function circulatingSupply() public view virtual override returns (uint) {
        return totalSupply();
    }

    function _debitFrom(address _from, uint16, bytes memory, uint _amount) internal virtual override returns(uint) {
        address spender = _msgSender();
        if (_from != spender) _spendAllowance(_from, spender, _amount);
        _burn(_from, _amount);
        return _amount;
    }

    function _creditTo(uint16, address _toAddress, uint _amount) internal virtual override returns(uint) {
        _mint(_toAddress, _amount);
        return _amount;
    }
}