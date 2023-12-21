// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/oft/OFTUpgradeable.sol";

import "./WadRayMath.sol";
import "../AddressAccessor.sol";
import "../constants/addresses.sol";
import "../constants/constants.sol";
import "../constants/roles.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/IUSDR.sol";
import "./WUSDR.sol";

contract USDR is
    AddressAccessorUpgradable,
    PausableUpgradeable,
    OFTUpgradeable,
    IUSDR
{
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    event Rebase(
        uint256 indexed blockNumber,
        uint256 indexed day,
        uint256 supply,
        uint256 supplyDelta,
        uint256 index
    );

    event SyncToChain(uint16 dstChainId, uint256 liquidityIndex);
    event SyncFromChain(uint16 srcChainId, uint256 liquidityIndex);

    address public constant MULTICHAIN_VAULT =
        0x52b9D0F46451bd2c610Ae6Ab1F5312a35A6159E3;

    address public constant PREVIOUS_WUSDR =
        0xAF0D9D65fC54de245cdA37af3d18cbEc860A4D4b;

    uint16 public constant PT_SYNC = 1;

    bool public isMain;
    bool private _preMinted;

    address public previousImplementation;

    uint256 private _totalSupply;
    uint256 private _totalSupplyScale;

    uint256 public liquidityIndex;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowedValue;

    function initialize(
        address _owner,
        address _previousImplementation,
        address _lzEndpoint,
        bool _isMainChain
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __OFTUpgradeable_init("Real USD", "USDR", _lzEndpoint);
        _transferOwnership(_owner);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        isMain = _isMainChain;
        previousImplementation = _previousImplementation;
        if (_previousImplementation != address(0)) {
            liquidityIndex = USDR(_previousImplementation).liquidityIndex();
        } else {
            liquidityIndex = 1e27;
        }
    }

    function reinitialize() external reinitializer(5) {
        if (!isMain) {
            _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
            _grantRole(DEFAULT_ADMIN_ROLE, owner());
        }
    }

    function resetInitialLiquidityIndex() external onlyOwner {
        require(isMain, "USDR: not main chain");
        address usdrImpl = addressProvider.getAddress(USDR_ADDRESS);
        require(usdrImpl != address(this));
        liquidityIndex = USDR(usdrImpl).liquidityIndex();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, OFTUpgradeable)
        returns (bool)
    {
        return
            AccessControlUpgradeable.supportsInterface(interfaceId) ||
            OFTUpgradeable.supportsInterface(interfaceId);
    }

    function burn(address account, uint256 amount) external whenNotPaused {
        require(account != address(0), "burn from zero address");

        if (msg.sender != account) {
            _spendAllowance(account, msg.sender, amount);
        }

        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "burn amount exceeds balance");

        if (accountBalance == amount) {
            _totalSupply -= _balances[account];
            delete _balances[account];
        } else {
            uint256 amount_ = amount.wadToRay().rayDiv(liquidityIndex);
            if (amount_ > _balances[account]) {
                amount_ = _balances[account];
            }
            _totalSupply -= amount_;
            _balances[account] -= amount_;
        }

        emit Transfer(account, address(0), amount);
    }

    function mint(address account, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        require(account != address(0), "mint to zero address");

        uint256 amount_ = amount.wadToRay().rayDiv(liquidityIndex);

        require(amount_ <= MAX_UINT128 - totalSupply(), "max supply exceeded");

        _totalSupply += amount_;
        _balances[account] += amount_;

        emit Transfer(address(0), account, amount);
    }

    function rebase(uint256 supplyDelta)
        external
        onlyRole(CONTROLLER_ROLE)
        whenNotPaused
    {
        uint256 ts = totalSupply();
        (address treasury, address exchange) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TREASURY_ADDRESS, USDR_EXCHANGE_ADDRESS)
            ),
            (address, address)
        );
        require(msg.sender == treasury, "caller is not treasury");
        if (supplyDelta > 0) {
            supplyDelta = IExchange(exchange).scaleFromUnderlying(supplyDelta);
            uint256 maxSupplyDelta = MAX_UINT128 - ts;
            if (supplyDelta > maxSupplyDelta) {
                supplyDelta = maxSupplyDelta;
            }
            if (supplyDelta > 0) {
                liquidityIndex = (liquidityIndex * (ts + supplyDelta)) / ts;
                int128[7] memory delta;
                delta[6] = int128(uint128(totalSupply() - ts));
                IExchange(exchange).updateMintingStats(delta);
            }
        }
        emit Rebase(
            block.number,
            block.timestamp / 1 days,
            ts,
            supplyDelta,
            liquidityIndex
        );
    }

    function sync(
        uint16 _dstChainId,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) public payable whenNotPaused {
        require(isMain, "USDR: can only sync from main chain");
        _sync(
            _dstChainId,
            liquidityIndex,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams
        );
    }

    function allowance(address owner_, address spender)
        public
        view
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (uint256)
    {
        return _allowedValue[owner_][spender];
    }

    function approve(address spender, uint256 value)
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        _allowedValue[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function balanceOf(address account)
        public
        view
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (uint256)
    {
        return _balances[account].rayMul(liquidityIndex).rayToWad();
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        returns (bool)
    {
        uint256 oldValue = _allowedValue[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            delete _allowedValue[msg.sender][spender];
        } else {
            _allowedValue[msg.sender][spender] = oldValue - subtractedValue;
        }
        emit Approval(msg.sender, spender, _allowedValue[msg.sender][spender]);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        returns (bool)
    {
        _allowedValue[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, _allowedValue[msg.sender][spender]);
        return true;
    }

    function totalSupply()
        public
        view
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (uint256)
    {
        uint256 _previous;
        if (previousImplementation != address(0)) {
            _previous =
                USDR(previousImplementation).totalSupply() -
                ERC4626(PREVIOUS_WUSDR).convertToAssets(
                    IERC20(PREVIOUS_WUSDR).balanceOf(MULTICHAIN_VAULT)
                );
        }
        return _totalSupply.rayMul(liquidityIndex).rayToWad() + _previous;
    }

    function transfer(address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        whenNotPaused
        returns (bool)
    {
        uint256 amount_ = _transferableAmount(amount, msg.sender);
        _balances[msg.sender] -= amount_;
        _balances[to] += amount_;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferAll(address to) public whenNotPaused returns (bool) {
        uint256 amount = balanceOf(msg.sender);
        uint256 amount_ = _balances[msg.sender];
        delete _balances[msg.sender];
        _balances[to] += amount_;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferAllFrom(address from, address to)
        public
        whenNotPaused
        returns (bool)
    {
        uint256 amount = balanceOf(from);
        uint256 amount_ = _balances[from];
        _spendAllowance(from, msg.sender, amount);
        delete _balances[from];
        _balances[to] += amount_;
        emit Transfer(from, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        whenNotPaused
        returns (bool)
    {
        _spendAllowance(from, msg.sender, amount);
        uint256 amount_ = _transferableAmount(amount, from);
        _balances[from] -= amount_;
        _balances[to] += amount_;
        emit Transfer(from, to, amount);
        return true;
    }

    function _transferableAmount(uint256 amount, address sender)
        internal
        view
        returns (uint256)
    {
        uint256 balance = balanceOf(sender);
        require(amount <= balance, "USDR: amount exceeds balance");
        if (amount == balanceOf(sender)) {
            return _balances[sender];
        }
        return amount.wadToRay().rayDiv(liquidityIndex);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual override {
        _allowedValue[owner][spender] = value;
        emit Approval(owner, spender, value);
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
        if (_from != msg.sender) _spendAllowance(_from, msg.sender, _amount);
        uint256 transferAmount = _transferableAmount(_amount, _from);
        if (isMain) {
            _balances[_from] -= transferAmount;
            _balances[address(this)] += transferAmount;
            emit Transfer(_from, address(this), _amount);
        } else {
            _totalSupply -= transferAmount;
            _balances[_from] -= transferAmount;
            emit Transfer(_from, address(0), _amount);
        }
        return transferAmount;
    }

    function _creditTo(
        uint16,
        address _toAddress,
        uint256 _amount
    ) internal override returns (uint256) {
        uint256 receivedAmount = _amount.rayMul(liquidityIndex).rayToWad();
        if (isMain) {
            _balances[address(this)] -= _amount;
            _balances[_toAddress] += _amount;
            emit Transfer(address(this), _toAddress, receivedAmount);
        } else {
            _totalSupply += _amount;
            _balances[_toAddress] += _amount;
            emit Transfer(address(0), _toAddress, receivedAmount);
        }
        return _amount;
    }

    function _sync(
        uint16 _dstChainId,
        uint256 _liquidityIndex,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) internal {
        _checkAdapterParams(_dstChainId, PT_SYNC, _adapterParams, NO_EXTRA_GAS);

        bytes memory lzPayload = abi.encode(PT_SYNC, _liquidityIndex);
        _lzSend(
            _dstChainId,
            lzPayload,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams,
            msg.value
        );

        emit SyncToChain(_dstChainId, _liquidityIndex);
    }

    function _syncAck(uint16 _srcChainId, bytes memory _payload) internal {
        (, uint256 _liquidityIndex) = abi.decode(_payload, (uint16, uint256));

        require(
            liquidityIndex <= _liquidityIndex,
            "USDR: liquidity index too low"
        );
        liquidityIndex = _liquidityIndex;

        emit SyncFromChain(_srcChainId, _liquidityIndex);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal override {
        uint16 packetType;
        assembly {
            packetType := mload(add(_payload, 32))
        }
        if (packetType == PT_SEND) {
            _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
        } else if (packetType == PT_SYNC) {
            _syncAck(_srcChainId, _payload);
        } else {
            revert("USDR: unknown packet type");
        }
    }
}
