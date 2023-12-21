// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/oft/OFTUpgradeable.sol";

import "./WadRayMath.sol";
import "../interfaces/IUSDR.sol";

contract WrappedUSDR is
    PausableUpgradeable,
    OFTUpgradeable,
    IERC4626Upgradeable
{
    using AddressUpgradeable for address;
    using WadRayMath for uint256;

    address public asset;

    function initialize(
        address _owner,
        address usdr,
        address lzEndpoint
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __OFTUpgradeable_init("Wrapped USDR", "wUSDR", lzEndpoint);
        _transferOwnership(_owner);
        asset = usdr;
    }

    function reinitialize() external reinitializer(4) {}

    function decimals()
        public
        pure
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (uint8)
    {
        return 9;
    }

    function totalAssets() external view override returns (uint256) {
        return _convertToAssetsDown(totalSupply());
    }

    function convertToShares(uint256 assets)
        external
        view
        override
        returns (uint256)
    {
        return _convertToSharesDown(assets);
    }

    function convertToAssets(uint256 shares)
        external
        view
        override
        returns (uint256)
    {
        return _convertToAssetsDown(shares);
    }

    function maxDeposit(
        address /*receiver*/
    ) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function previewDeposit(uint256 assets)
        external
        view
        override
        returns (uint256)
    {
        return _convertToSharesDown(assets);
    }

    function deposit(uint256 assets, address receiver)
        external
        override
        whenNotPaused
        returns (uint256 shares)
    {
        require(
            receiver != address(0),
            "Zero address for receiver not allowed"
        );

        _pullAssets(msg.sender, assets);
        shares = _convertToSharesDown(assets);

        if (shares != 0) {
            _mint(receiver, shares);
        }

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function maxMint(
        address /*receiver*/
    ) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function previewMint(uint256 shares)
        external
        view
        override
        returns (uint256)
    {
        return _convertToAssetsUp(shares);
    }

    function mint(uint256 shares, address receiver)
        external
        override
        whenNotPaused
        returns (uint256 assets)
    {
        require(
            receiver != address(0),
            "Zero address for receiver not allowed"
        );

        assets = _convertToAssetsUp(shares);

        if (assets != 0) {
            _pullAssets(msg.sender, assets);
        }

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function maxWithdraw(address owner)
        external
        view
        override
        returns (uint256)
    {
        return _convertToAssetsDown(balanceOf(owner));
    }

    function previewWithdraw(uint256 assets)
        external
        view
        override
        returns (uint256)
    {
        return _convertToSharesUp(assets);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external override whenNotPaused returns (uint256 shares) {
        require(
            receiver != address(0),
            "Zero address for receiver not allowed"
        );
        require(owner != address(0), "Zero address for owner not allowed");

        shares = _convertToSharesUp(assets);

        if (owner != msg.sender) {
            uint256 currentAllowance = allowance(owner, msg.sender);
            require(
                currentAllowance >= shares,
                "Withdraw amount exceeds allowance"
            );
            _approve(owner, msg.sender, currentAllowance - shares);
        }

        if (shares != 0) {
            _burn(owner, shares);
        }

        _pushAssets(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function maxRedeem(address owner) external view override returns (uint256) {
        return balanceOf(owner);
    }

    function previewRedeem(uint256 shares)
        external
        view
        override
        returns (uint256)
    {
        return _convertToAssetsDown(shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external override whenNotPaused returns (uint256 assets) {
        require(
            receiver != address(0),
            "Zero address for receiver not allowed"
        );
        require(owner != address(0), "Zero address for owner not allowed");

        if (owner != msg.sender) {
            uint256 currentAllowance = allowance(owner, msg.sender);
            require(
                currentAllowance >= shares,
                "Redeem amount exceeds allowance"
            );
            _approve(owner, msg.sender, currentAllowance - shares);
        }

        _burn(owner, shares);

        assets = _convertToAssetsDown(shares);

        if (assets != 0) {
            _pushAssets(receiver, assets);
        }

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _getRate() private view returns (uint256) {
        bytes memory data = asset.functionStaticCall(
            abi.encodeWithSignature("liquidityIndex()")
        );
        return abi.decode(data, (uint256));
    }

    function _convertToSharesUp(uint256 assets) private view returns (uint256) {
        return assets.rayDiv(_getRate());
    }

    function _convertToAssetsUp(uint256 shares) private view returns (uint256) {
        return shares.rayMul(_getRate());
    }

    function _convertToSharesDown(uint256 assets)
        private
        view
        returns (uint256)
    {
        return (assets * WadRayMath.RAY) / _getRate();
    }

    function _convertToAssetsDown(uint256 shares)
        private
        view
        returns (uint256)
    {
        return (shares * _getRate()) / WadRayMath.RAY;
    }

    function _pullAssets(address from, uint256 amount) private {
        asset.functionCall(
            abi.encodeWithSelector(
                IERC20Upgradeable.transferFrom.selector,
                from,
                address(this),
                amount
            )
        );
    }

    function _pushAssets(address to, uint256 amount) private {
        asset.functionCall(
            abi.encodeWithSelector(
                IERC20Upgradeable.transfer.selector,
                to,
                amount
            )
        );
    }

    ///
    /// LayerZero overrides
    ///

    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) public payable override whenNotPaused {
        _send(
            _from,
            _dstChainId,
            _toAddress,
            _amount,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams
        );
    }

    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint256 _amount
    ) internal override returns (uint256) {
        address spender = _msgSender();
        if (_from != spender) _spendAllowance(_from, spender, _amount);
        _transfer(_from, address(this), _amount);
        return _amount;
    }

    function _creditTo(
        uint16,
        address _toAddress,
        uint256 _amount
    ) internal override returns (uint256) {
        _transfer(address(this), _toAddress, _amount);
        return _amount;
    }
}
