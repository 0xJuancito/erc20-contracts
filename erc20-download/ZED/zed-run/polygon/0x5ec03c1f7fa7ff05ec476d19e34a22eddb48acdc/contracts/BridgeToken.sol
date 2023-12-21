// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./common/ERC20Bridge.sol";
import "./interfaces/IChildToken.sol";
import "./common/EIP712MetaTransaction.sol";

// BridgeToken is Capped
contract BridgeToken is ERC20Bridge, IChildToken, EIP712MetaTransaction {
    uint256 private immutable _cap;

    address public childChainManagerProxy;

    constructor(
        string memory _erc20Name,
        string memory _erc20Symbol,
        uint8 _decimals,
        uint256 cap_,
        address[] memory _mintAddresses,
        uint256[] memory _mintAmounts,
        address _childChainManagerProxy
    ) ERC20Bridge(_erc20Name, _erc20Symbol, _decimals)  {
        require(_mintAddresses.length == _mintAmounts.length, "must have same number of mint addresses and amounts");
        require(address(0) != _childChainManagerProxy, "manager proxy is undefined");

        require(cap_ > 0, "ERC20Capped: cap is 0");
        _cap = cap_;

        childChainManagerProxy = _childChainManagerProxy;

        for (uint i; i < _mintAddresses.length; i++) {
            require(_mintAddresses[i] != address(0), "cannot have a non-address as reserve");
            _mint(_mintAddresses[i], _mintAmounts[i]);
        }

        require(cap_ >= totalSupply(), "total supply of tokens cannot exceed the cap");
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    function deposit(address user, bytes calldata depositData) override external {
        require(_msgSender() == childChainManagerProxy, "You're not allowed to deposit");

        uint256 amount = abi.decode(depositData, (uint256));

        require(cap() >= this.totalSupply() + amount, "ERC20Capped: cap exceeded");

        _mint(user, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function _msgSender() internal view override returns (address sender) {
        return EIP712MetaTransaction.msgSender();
    }
}
