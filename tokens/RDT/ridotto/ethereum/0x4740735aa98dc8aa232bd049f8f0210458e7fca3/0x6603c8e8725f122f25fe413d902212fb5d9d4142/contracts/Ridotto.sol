// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './UsingLiquidityProtectionService.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';


contract Ridotto is ERC20PresetMinterPauserUpgradeable, UsingLiquidityProtectionService {
    bytes32 public constant PROTECTION_ADMIN_ROLE = keccak256('PROTECTION_ADMIN_ROLE');
    // Setup a sender role allocated to the token master wallet and ido contract.
    // These are the only two addresses with right to send tokens until liquidity is deployed.
    bytes32 public constant SENDER_ROLE = keccak256("SENDER_ROLE");

    // flag to check if liquidity is deployed. One time flag that stays at true even if liquidity is removed later.
    bool public liquidityDeployed;

    function __Ridotto_init(address _nextOwner, address _idoContract) public initializer {
        __ERC20PresetMinterPauser_init('Ridotto', 'RDT');
        _setupRole(DEFAULT_ADMIN_ROLE, _nextOwner);
        _setupRole(MINTER_ROLE, _nextOwner);
        _setupRole(PAUSER_ROLE, _nextOwner);
        _setupRole(PROTECTION_ADMIN_ROLE, _nextOwner);
        _setupRole(PROTECTION_ADMIN_ROLE, _msgSender());
        LiquidityProtection_setLiquidityProtectionService(IPLPS(0x545CF6Af0a9090F465E1fBC9aA173a611F29081c));
        revokeRole(MINTER_ROLE, _msgSender());
        revokeRole(PAUSER_ROLE, _msgSender());
        revokeRole(PROTECTION_ADMIN_ROLE, _msgSender());
        revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(SENDER_ROLE, address(0));
        _mint(_nextOwner, 500000000 * 1e18);
        // initialize the value of the liquidity pool to the Uniswap V2 pool for the token.
        // setup the sender role for the owner the tokens aka token master wallet.
        _setupRole(SENDER_ROLE, _nextOwner);
        // setup the sender role for the IDO contract which can distribute locked tokens to the IDO participants.
        _setupRole(SENDER_ROLE, _idoContract);
    }

    function token_transfer(address _from, address _to, uint _amount) internal override {
        _transfer(_from, _to, _amount); // Expose low-level token transfer function.
    }
    function token_balanceOf(address _holder) internal view override returns(uint) {
        return balanceOf(_holder); // Expose balance check function.
    }
    function protectionAdminCheck() internal view override onlyRole(PROTECTION_ADMIN_ROLE) {} // Must revert to deny access.
    function uniswapVariety() internal pure override returns(bytes32) {
        return UNISWAP; // UNISWAP / PANCAKESWAP / QUICKSWAP.
    }
    function uniswapVersion() internal pure override returns(UniswapVersion) {
        return UniswapVersion.V2; // V2 or V3.
    }
    function uniswapFactory() internal pure override returns(address) {
        return 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Replace with the correct address.
    }
    function _beforeTokenTransfer(address _from, address _to, uint _amount) internal override {
        super._beforeTokenTransfer(_from, _to, _amount);
        // If liquidity is added to Uniswap v2 pool, set the flag to true so that no further locks are present on tokens
        if (balanceOf(getLiquidityPool()) != 0) {
            liquidityDeployed = true;
        }
        // If the one time liquididy added flag is not set, ensure that the sender has the sender role set.
        if (!liquidityDeployed) { require(hasRole(SENDER_ROLE, _from),"RDT: transfers are disabled"); }
        LiquidityProtection_beforeTokenTransfer(_from, _to, _amount);
    }
    // All the following overrides are optional, if you want to modify default behavior.

    // How the protection gets disabled.
    function protectionChecker() internal view override returns(bool) {
        return ProtectionSwitch_timestamp(1636675199); // Switch off protection on Thursday, November 11, 2021 11:59:59 PM GMT.
        // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
        //        return ProtectionSwitch_manual(); // Switch off protection by calling disableProtection(); from owner. Default.
    }

    // This token will be pooled in pair with:
    function counterToken() internal pure override returns(address) {
        return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    }
}

contract RidottoDeployer {
    event Deployed(address rdt, address proxyAdmin);
    constructor(address _nextOwner, address _idoContract) {
        Ridotto rdt = new Ridotto();
        ProxyAdmin admin = new ProxyAdmin();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(rdt), address(admin), abi.encodeWithSelector(rdt.__Ridotto_init.selector, _nextOwner, _idoContract));
        admin.transferOwnership(_nextOwner);
        emit Deployed(address(proxy), address(admin));
    }
}
