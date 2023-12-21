// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;


import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


import "./lib/ERC1363Upgradable.sol";

contract ConiToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, ERC1363Upgradable {

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant EDITOR_ROLE = keccak256("EDITOR_ROLE");
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");


    mapping (address => bool) public paymentPartners;
    mapping (address => bool) public suspendedWallets;

    bool private $isOnlyWhitelist;



    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address direconIncVault) initializer public {
        __ERC20_init("ConiToken", "CONI");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("ConiToken");
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(EDITOR_ROLE, msg.sender);


        _grantRole(WHITELIST_ROLE, direconIncVault);
        _grantRole(EDITOR_ROLE, direconIncVault);


        // MINT 100M tokens to Direcon Inc. vault for distribution
        _mint(direconIncVault, 1 * 10 ** 26);
        $isOnlyWhitelist = true;
    }

    // ** Management functions **

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setOnlyWhitelist(bool isOnlyWhitelist) public onlyRole(EDITOR_ROLE) {
        $isOnlyWhitelist = isOnlyWhitelist;
    }

    function addPaymentPartner(address paymentGateway) public onlyRole(EDITOR_ROLE) {
        paymentPartners[paymentGateway] = true;
    }

    function removePaymentPartner(address paymentGateway) public onlyRole(EDITOR_ROLE) {
        paymentPartners[paymentGateway] = false;
    }

    function addSuspendedWallet (address walletAddress) public onlyRole(EDITOR_ROLE) {
        suspendedWallets[walletAddress] = true;
    }

    function removeSuspendedWallet (address walletAddress) public onlyRole(EDITOR_ROLE) {
        suspendedWallets[walletAddress] = false;
    }

    // ** Overrides **
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1363Upgradable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _checkOnTransferReceived(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data
    ) internal override(ERC1363Upgradable) virtual returns (bool) {
        if (!paymentPartners[recipient]) {
            return false;
        }
        return super._checkOnTransferReceived(sender, recipient, amount, data);
    }

    function _checkOnApprovalReceived(
        address spender,
        uint256 amount,
        bytes memory data
    ) internal override(ERC1363Upgradable) virtual returns (bool) {
        if (!paymentPartners[spender]) {
            return false;
        }
        return super._checkOnApprovalReceived(spender, amount, data);
    }


    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        if ($isOnlyWhitelist) {
            // tx.origin because we want to allow any transaction came from whitelisted wallet with any contract
            require(hasRole(WHITELIST_ROLE, tx.origin), 'Only wallets with whitelist role can transfer tokens');
        }
        if (suspendedWallets[from] || suspendedWallets[to]) {
            revert("Wallet is suspended");
        }
        super._beforeTokenTransfer(from, to, amount);
    }


}