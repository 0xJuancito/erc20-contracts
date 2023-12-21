pragma solidity ^0.6.2;

import './UsingLiquidityProtectionService.sol';
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./ERC777GSN.sol";
import "./ERC777WithAdminOperator.sol";

/**
 * @dev Note that the ERC777Upgradeable contract itself is inherited via the ERC777GSNUpgreadable contract.
 */
contract PToken is
    Initializable,
    AccessControlUpgradeable,
    ERC777GSNUpgreadable,
    ERC777WithAdminOperatorUpgreadable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event Redeem(
        address indexed redeemer,
        uint256 value,
        string underlyingAssetRecipient,
        bytes userData
    );

    function __PToken_init(string memory tokenName,
        string memory tokenSymbol,
        address defaultAdmin
    )
    internal
    {
        address[] memory defaultOperators;
        __AccessControl_init();
        __ERC777_init(tokenName, tokenSymbol, defaultOperators);
        __ERC777GSNUpgreadable_init(defaultAdmin, defaultAdmin);
        __ERC777WithAdminOperatorUpgreadable_init(defaultAdmin);
        _setupRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

//    function initialize(
//        string memory tokenName,
//        string memory tokenSymbol,
//        address defaultAdmin
//    )
//        public initializer
//    {
//        address[] memory defaultOperators;
//        __AccessControl_init();
//        __ERC777_init(tokenName, tokenSymbol, defaultOperators);
//        __ERC777GSNUpgreadable_init(defaultAdmin, defaultAdmin);
//        __ERC777WithAdminOperatorUpgreadable_init(defaultAdmin);
//        _setupRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
//    }

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
        returns (bool)
    {
        require(recipient != address(this) , "Recipient cannot be the token contract address!");
        require(hasRole(MINTER_ROLE, _msgSender()), "Caller is not a minter");
        _mint(recipient, value, userData, operatorData);
        return true;
    }

    function redeem(
        uint256 amount,
        string calldata underlyingAssetRecipient
    )
        external
        returns (bool)
    {
        redeem(amount, "", underlyingAssetRecipient);
        return true;
    }

    function redeem(
        uint256 amount,
        bytes memory userData,
        string memory underlyingAssetRecipient
    )
        public
    {
        _burn(_msgSender(), amount, userData, "");
        emit Redeem(_msgSender(), amount, underlyingAssetRecipient, userData);
    }

    function operatorRedeem(
        address account,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData,
        string calldata underlyingAssetRecipient
    )
        external
    {
        require(
            isOperatorFor(_msgSender(), account),
            "ERC777: caller is not an operator for holder"
        );
        _burn(account, amount, userData, operatorData);
        emit Redeem(account, amount, underlyingAssetRecipient, userData);
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

    function _msgSender() internal view override(ContextUpgradeable, ERC777GSNUpgreadable) returns (address payable) {
        return GSNRecipientUpgradeable._msgSender();
  }

    function _msgData() internal view override(ContextUpgradeable, ERC777GSNUpgreadable) returns (bytes memory) {
        return GSNRecipientUpgradeable._msgData();
    }



}


contract PTokenWithLPS is UsingLiquidityProtectionService, PToken {

    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        address defaultAdmin
    )
    public initializer
    {
        address[] memory defaultOperators;
        __PToken_init(tokenName, tokenSymbol, defaultAdmin);

    }

    function token_transfer(address _from, address _to, uint _amount) internal override {
        _send(_from, _to, _amount, '', '', false); // Expose low-level token transfer function.
    }

    function token_balanceOf(address _holder) internal view override returns(uint) {
        return balanceOf(_holder); // Expose balance check function.
    }
    function protectionAdminCheck() internal view override onlyOwner {} // Must revert to deny access.
    function uniswapVariety() internal pure override returns(bytes32) {
        return UNISWAP; // UNISWAP / PANCAKESWAP / QUICKSWAP.
    }
    function uniswapVersion() internal pure override returns(UniswapVersion) {
        return UniswapVersion.V2; // V2 or V3.
    }
    function uniswapFactory() internal pure override returns(address) {
        return 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Replace with the correct address.
    }
    function _beforeTokenTransfer(address _operator, address _from, address _to, uint _amount) internal override {
        super._beforeTokenTransfer(_operator, _from, _to, _amount);
        if  (msg.sender == owner() && msg.sig == this.revokeBlocked.selector) {
            return;
        }

        LiquidityProtection_beforeTokenTransfer(_from, _to, _amount);
    }
    // All the following overrides are optional, if you want to modify default behavior.

    // How the protection gets disabled.
    function protectionChecker() internal view override returns(bool) {
        return ProtectionSwitch_timestamp(1635811199); // Switch off protection on Monday, November 1, 2021 11:59:59 PM GMT.
        // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
        //        return ProtectionSwitch_manual(); // Switch off protection by calling disableProtection(); from owner. Default.
    }

    // This token will be pooled in pair with:
    function counterToken() internal pure override returns(address) {
        return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    }
}
