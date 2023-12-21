pragma solidity ^0.6.2;

import "./ERC777GSN.sol";
import "./ERC777WithAdminOperatorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract PToken is
    Initializable,
    AccessControlUpgradeable,
    ERC777GSNUpgradeable,
    ERC777WithAdminOperatorUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes4 public ORIGIN_CHAIN_ID;

    event Redeem(
        address indexed redeemer,
        uint256 value,
        string underlyingAssetRecipient,
        bytes userData,
        bytes4 originChainId,
        bytes4 destinationChainId
    );

    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        address defaultAdmin,
        bytes4 originChainId
    )
        public initializer
    {
        address[] memory defaultOperators;
        __AccessControl_init();
        __ERC777_init(tokenName, tokenSymbol, defaultOperators);
        __ERC777GSNUpgradeable_init(defaultAdmin, defaultAdmin);
        __ERC777WithAdminOperatorUpgradeable_init(defaultAdmin);
        _setupRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        ORIGIN_CHAIN_ID = originChainId;
    }

    modifier onlyMinter {
        require(hasRole(MINTER_ROLE, _msgSender()), "Caller is not a minter");
        _;
    }

    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not an admin");
        _;
    }

    function mint(
        address recipient,
        uint256 value
    )
        external
        returns (bool)
    {
        mint(recipient, value, "", "");
        return true;
    }

    function mint(
        address recipient,
        uint256 value,
        bytes memory userData,
        bytes memory operatorData
    )
        public
        onlyMinter
        returns (bool)
    {
        require(
            recipient != address(this) ,
            "Recipient cannot be the token contract address!"
        );
        _mint(recipient, value, userData, operatorData);
        return true;
    }

    function redeem(
        uint256 amount,
        string calldata underlyingAssetRecipient,
        bytes4 destinationChainId
    )
        external
        returns (bool)
    {
        redeem(amount, "", underlyingAssetRecipient, destinationChainId);
        return true;
    }

    function redeem(
        uint256 amount,
        bytes memory userData,
        string memory underlyingAssetRecipient,
        bytes4 destinationChainId
    )
        public
    {
        _burn(_msgSender(), amount, userData, "");
        emit Redeem(
            _msgSender(),
            amount,
            underlyingAssetRecipient,
            userData,
            ORIGIN_CHAIN_ID,
            destinationChainId
        );
    }

    function operatorRedeem(
        address account,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData,
        string calldata underlyingAssetRecipient,
        bytes4 destinationChainId
    )
        external
    {
        require(
            isOperatorFor(_msgSender(), account),
            "ERC777: caller is not an operator for holder"
        );
        _burn(account, amount, userData, operatorData);
        emit Redeem(account, amount, underlyingAssetRecipient, userData, ORIGIN_CHAIN_ID, destinationChainId);
    }

    function grantMinterRole(address _account) external {
        grantRole(MINTER_ROLE, _account);
    }

    function revokeMinterRole(address _account) external {
        revokeRole(MINTER_ROLE, _account);
    }

    function hasMinterRole(address _account) external view returns (bool) {
        return hasRole(MINTER_ROLE, _account);
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC777GSNUpgradeable)
        returns (address payable)
    {
        return GSNRecipientUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC777GSNUpgradeable)
        returns (bytes memory)
    {
        return GSNRecipientUpgradeable._msgData();
    }

    function changeOriginChainId(
        bytes4 _newOriginChainId
    )
        public
        onlyAdmin
        returns (bool success)
    {
        ORIGIN_CHAIN_ID = _newOriginChainId;
        return true;
    }
}
