// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { IArbSys, IArbToken } from "./IArbitrum.sol";

/**
 * @dev An empty MCB token without mint
 */
contract ArbMCBv1 is ERC20Upgradeable {
    function init() public initializer {
        __ERC20_init("MCDEX Token", "MCB");
    }
}

abstract contract L2ArbitrumMessenger {
    address internal constant arbSysAddr = address(100);

    event TxToL1(
        address indexed _from,
        address indexed _to,
        uint256 indexed _id,
        bytes _data
    );

    function sendTxToL1(
        uint256 _l1CallValue,
        address _from,
        address _to,
        bytes memory _data
    ) internal virtual returns (uint256) {
        uint256 _id = IArbSys(arbSysAddr).sendTxToL1{ value: _l1CallValue }(
            _to,
            _data
        );
        emit TxToL1(_from, _to, _id, _data);
        return _id;
    }
}

/**
 * @dev MCB token v2
 */
contract ArbMCBv2 is
    ERC20Upgradeable,
    AccessControlUpgradeable,
    L2ArbitrumMessenger,
    IArbToken
{
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public l1Token;
    address public gateway;
    uint256 public tokenSupplyOnL1;

    event BridgeMint(address indexed account, uint256 amount);
    event BridgeBurn(address indexed account, uint256 amount);
    event L1EscrowMint(
        address indexed l1Token,
        uint256 indexed withdrawalId,
        uint256 amount
    );

    function migrateToArb(
        address gateway_,
        address l1Token_,
        uint256 tokenSupplyOnL1_
    ) external {
        __ArbMCBv2_init_unchained(gateway_, l1Token_, tokenSupplyOnL1_);
    }

    /**
     * @dev initialze addresses && roles
     */
    function __ArbMCBv2_init_unchained(
        address gateway_,
        address l1Token_,
        uint256 tokenSupplyOnL1_
    ) internal {
        require(gateway == address(0), "already migrated");
        require(l1Token == address(0), "already migrated");
        require(tokenSupplyOnL1 == 0, "already migrated");
        require(gateway_.isContract(), "gateway must be contract");
        require(l1Token_ != address(0), "l1Token must be non-zero address");

        gateway = gateway_;
        l1Token = l1Token_;
        tokenSupplyOnL1 = tokenSupplyOnL1_;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
    }

    modifier onlyGateway() {
        require(msg.sender == gateway, "caller must be gateway");
        _;
    }

    /**
     * @notice Method for token bridge.
     */
    function bridgeMint(
        address account,
        uint256 amount
    ) external override onlyGateway {
        // transfer from l1:
        // tokenSupplyOnL1 -= amount
        // totalSupllyOnL2 += amount
        // globalSupply stay unchanged
        tokenSupplyOnL1 = tokenSupplyOnL1.sub(amount);
        _mint(account, amount);
        emit BridgeMint(account, amount);
    }

    /**
     * @notice Method for token bridge.
     */
    function bridgeBurn(
        address account,
        uint256 amount
    ) external override onlyGateway {
        // transfer to l1:
        // tokenSupplyOnL1 += amount
        // totalSupllyOnL2 -= amount
        // globalSupply stay unchanged
        tokenSupplyOnL1 = tokenSupplyOnL1.add(amount);
        _burn(account, amount);
        emit BridgeBurn(account, amount);
    }

    /**
     * @notice Method for token bridge.
     */
    function l1Address() external view override returns (address) {
        return l1Token;
    }

    /**
     * @notice  Mint token on arb (l2), and send a cross-chain tx to mint the same amount token to gateway.
     */
    function mint(address to, uint256 amount) public virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "must have minter role to mint"
        );
        // transfer to l1:
        // tokenSupplyOnL1 stay unchanged
        // totalSupllyOnL2 += amount
        // globalSupply += amount
        _mint(to, amount);
        // mint to gateway on L1
        uint256 id = sendTxToL1(
            0,
            address(this),
            l1Token,
            _getOutboundCalldata(amount)
        );
        emit L1EscrowMint(l1Token, id, amount);
    }

    function _getOutboundCalldata(
        uint256 amount
    ) internal pure virtual returns (bytes memory) {
        return abi.encodeWithSignature("escrowMint(uint256)", amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable) {
        super._beforeTokenTransfer(from, to, amount);

        // proposal 2023-07-17: reject anyMCB
        require(
            from != 0xD7c295E399CA928A3a14b01D760E794f1AdF8990 &&
                to != 0xD7c295E399CA928A3a14b01D760E794f1AdF8990,
            "anyMCB"
        );
    }

    // 2023-11-06: rename the token name
    function name() public view virtual override returns (string memory) {
        return "MUX Protocol";
    }

    uint256[50] private __gap;
}
