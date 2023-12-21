// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol';
import '@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import './UsingLiquidityProtectionService.sol';

contract SugarBounceToken is
    ERC20PresetMinterPauser,
    IERC20Permit,
    EIP712,
    UsingLiquidityProtectionService(0x758a4c3c442D0B10627d173f11D8c1734979C8cC)
{
    using Counters for Counters.Counter;

    uint256 private constant _cap = 199000000 ether;
    string private constant _name = 'SugarBounce';
    string private constant _symbol = 'TIP';

    mapping(address => Counters.Counter) private _nonces;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _PERMIT_TYPEHASH =
        keccak256(
            'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
        );

    constructor() ERC20PresetMinterPauser(_name, _symbol) EIP712(_name, '1') {}

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public pure returns (uint256) {
        return _cap;
    }

    /**
     * @dev Returns the bep20 token owner
     */
    function getOwner() external view returns (address) {
        return super.getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    /**
     * @dev See {ERC20PresetMinterPauser-_mint}.
     */
    function _mint(address account, uint256 amount) internal override {
        require(
            ERC20.totalSupply() + amount <= cap(),
            'ERC20Capped: cap exceeded'
        );
        super._mint(account, amount);
    }

    /**
     * @dev See {IERC20Permit-permit}.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        require(block.timestamp <= deadline, 'ERC20Permit: expired deadline');

        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _useNonce(owner),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, 'ERC20Permit: invalid signature');

        _approve(owner, spender, value);
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view override returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     */
    function _useNonce(address owner) internal returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    /**
     * @dev Expose low-level token transfer function
     */
    function token_transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        _transfer(_from, _to, _amount);
    }

    /**
     * @dev Expose balance check function
     */
    function token_balanceOf(address _holder)
        internal
        view
        override
        returns (uint256)
    {
        return balanceOf(_holder);
    }

    /**
     * @dev Check the Admin access - Must revert to deny access
     */
    function protectionAdminCheck()
        internal
        view
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    /**
     * @dev DEX Variety - UNISWAP / PANCAKESWAP / QUICKSWAP / SUSHISWAP
     */
    function uniswapVariety() internal pure override returns (bytes32) {
        return PANCAKESWAP;
    }

    /**
     * @dev DEX version - V2 / V3
     */
    function uniswapVersion() internal pure override returns (UniswapVersion) {
        return UniswapVersion.V2;
    }

    /**
     * @dev DEX factory address
     */
    function uniswapFactory() internal pure override returns (address) {
        return 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73; // Replace with the correct address.
    }

    /**
     @dev Hook that is called before any transfer of tokens
     */
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        super._beforeTokenTransfer(_from, _to, _amount);
        LiquidityProtection_beforeTokenTransfer(_from, _to, _amount);
    }

    /**
     @dev How the protection gets disabled
     */
    function protectionChecker() internal view override returns (bool) {
        return ProtectionSwitch_timestamp(1639958399); // Switch off protection on Sunday, December 19, 2021 11:59:59 PM GMT.
        // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
        // return ProtectionSwitch_manual(); // Switch off protection by calling disableProtection(); from owner. Default.
    }

    /**
     * @dev Pair token address - This token will be pooled in pair with:
     */
    function counterToken() internal pure override returns (address) {
        return 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB
    }
}
