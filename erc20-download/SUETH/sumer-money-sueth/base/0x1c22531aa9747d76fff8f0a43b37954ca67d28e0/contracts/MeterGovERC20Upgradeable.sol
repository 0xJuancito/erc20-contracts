// Copyright (c) 2018 The Meter.io developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "./interfaces/IMeterNative.sol";

/// @title Meter implements VIP180(ERC20) standard, to present Meter/ Meter Gov tokens.
contract MeterGovERC20Upgradeable is
    IERC20Upgradeable,
    EIP712Upgradeable,
    AccessControlEnumerableUpgradeable
{
    mapping(address => mapping(address => uint256)) allowed;
    IMeterNative _meterTracker;
    mapping(address => bool) private blackList;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "forbidden");
        _;
    }

    function initialize() public initializer {
        __EIP712_init(name(), "v1.0");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _meterTracker = IMeterNative(
            0x0000000000000000004D657465724e6174697665
        );
    }

    function name() public pure returns (string memory) {
        return "MeterGov";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function symbol() public pure returns (string memory) {
        return "MTRG";
    }

    function totalSupply() public view override returns (uint256) {
        return _meterTracker.native_mtrg_totalSupply();
    }

    // @return energy that total burned.
    function totalBurned() public view returns (uint256) {
        return _meterTracker.native_mtrg_totalBurned();
    }

    function balanceOf(address _owner)
        public
        view
        override
        returns (uint256 balance)
    {
        return _meterTracker.native_mtrg_get(_owner);
    }

    function transfer(address _to, uint256 _amount)
        public
        override
        returns (bool success)
    {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override returns (bool success) {
        require(
            allowed[_from][msg.sender] >= _amount,
            "builtin: insufficient allowance"
        );
        allowed[_from][msg.sender] -= _amount;

        _transfer(_from, _to, _amount);
        return true;
    }

    function allowance(address _owner, address _spender)
        public
        view
        override
        returns (uint256 remaining)
    {
        return allowed[_owner][_spender];
    }

    function approve(address _spender, uint256 _value)
        public
        override
        returns (bool success)
    {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        require(!blackList[_from], "forbidden");
        if (_amount > 0) {
            require(
                _meterTracker.native_mtrg_sub(_from, _amount),
                "builtin: insufficient balance"
            );
            // believed that will never overflow
            _meterTracker.native_mtrg_add(_to, _amount);
        }
        emit Transfer(_from, _to, _amount);
    }

    function setBlackList(address account) public onlyAdmin {
        blackList[account] = !blackList[account];
    }

    function getBlackList(address account)
        public
        view
        onlyAdmin
        returns (bool)
    {
        return blackList[account];
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) external returns (bool) {
        require(deadline >= block.timestamp, "expired!");
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner]++,
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSAUpgradeable.recover(hash, signature);
        require(owner == signer, "Permit: invalid signature");
        allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
        return true;
    }
}
