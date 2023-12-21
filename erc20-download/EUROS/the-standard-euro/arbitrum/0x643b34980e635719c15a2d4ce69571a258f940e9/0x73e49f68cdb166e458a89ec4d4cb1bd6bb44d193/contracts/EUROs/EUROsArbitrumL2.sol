// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "contracts/interfaces/Arbitrum.sol";

contract EUROsArbitrumL2 is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable, AccessControlUpgradeable, IArbitrumL2Token {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    address public l2Gateway;
    address public override l1Address;

    modifier onlyL2Gateway() {
        require(msg.sender == l2Gateway, "NOT_GATEWAY");
        _;
    }

    function initialize(string memory _name, string memory _symbol, address _l2Gateway, address _l1Address) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();

        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        l2Gateway = _l2Gateway;
        l1Address = _l1Address;
    }

    function _authorizeUpgrade(address) internal view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "invalid-admin");
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender), "invalid-minter");
        _mint(to, amount);
    }

    function addMinter(address _address) public {
        grantRole(MINTER_ROLE, _address);
    }

    function removeMinter(address _address) public {
        revokeRole(MINTER_ROLE, _address);
    }

    function burn(address from, uint256 amount) public {
        require(hasRole(BURNER_ROLE, msg.sender), "invalid-burner");
        _burn(from, amount);
    }

    function addBurner(address _address) public {
        grantRole(BURNER_ROLE, _address);
    }

    function removeBurner(address _address) public {
        revokeRole(BURNER_ROLE, _address);
    }

    function bridgeMint(
        address account,
        uint256 amount
    ) external override onlyL2Gateway {
        _mint(account, amount);
    }

    function bridgeBurn(
        address account,
        uint256 amount
    ) external override onlyL2Gateway {
        _burn(account, amount);
    }
}
