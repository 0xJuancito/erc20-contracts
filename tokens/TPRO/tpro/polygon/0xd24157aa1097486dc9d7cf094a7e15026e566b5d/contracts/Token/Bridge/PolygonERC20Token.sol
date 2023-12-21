// SPDX-License-Identifier: MIT

pragma solidity =0.8.6;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import "../Token.sol";
import "../../Bridge/Polygon/IFxERC20.sol";

contract PolygonERC20Token is Token, IFxERC20, AccessControl {
    using Address for address;

    address internal _fxManager;
    address internal _connectedToken;

    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(uint256 amount, string memory name, string memory symbol, uint8 dec) Token(amount, name, symbol, dec) {
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, ADMIN_ROLE);

        _setupRole(ADMIN_ROLE, address(this));
        _setupRole(ADMIN_ROLE, owner());
    }

    function initialize(
        address fxManager_,
        address connectedToken_,
        string memory /**name_**/,
        string memory /**symbol_**/,
        uint8 /**decimals_**/
    ) public virtual override {
        require(_fxManager == address(0x0) && _connectedToken == address(0x0), "Token is already initialized");
        _fxManager = fxManager_;
        _connectedToken = connectedToken_;
        _isWhitelisted[_fxManager] = true;
        bytes4 selector = this.grantRole.selector;
        address(this).functionCall(abi.encodeWithSelector(selector, MINTER_ROLE, _fxManager));
        address(this).functionCall(abi.encodeWithSelector(selector, BURNER_ROLE, _fxManager));
    }

    // fxManager returns fx manager
    function fxManager() public view virtual override returns (address) {
        return _fxManager;
    }

    // connectedToken returns root token
    function connectedToken() public view virtual override returns (address) {
        return _connectedToken;
    }

    function mint(address user, uint256 amount) public virtual override onlyRole(MINTER_ROLE) {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) public virtual override onlyRole(BURNER_ROLE) {
        _burn(user, amount);
    }


    function burn(uint256 amount) public virtual override {
        revert('ERC20: ChildToken cannot be burnt, please burn root tokens instead');
    }

    function burnFrom(address account, uint256 amount) public virtual override {
        revert('ERC20: ChildToken cannot be burnt, please burn root tokens instead');
    }
}
