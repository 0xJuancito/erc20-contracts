// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/gFly/IGFly.sol";
import "../interfaces/gFly/IVestedGFly.sol";

//MMMMWKl.                                            .:0WMMMM//
//MMMWk,                                                .dNMMM//
//MMNd.                                                  .lXMM//
//MWd.    .','''....                         .........    .lXM//
//Wk.     ';......'''''.                ..............     .dW//
//K;     .;,         ..,'.            ..'..         ...     'O//
//d.     .;;.           .''.        ..'.            .'.      c//
//:       .','.           .''.    ..'..           ....       '//
//'         .';.            .''...'..           ....         .//
//.           ';.             .''..             ..           .//
//.            ';.                             ...           .//
//,            .,,.                           .'.            .//
//c             .;.                           '.             ;//
//k.            .;.             .             '.            .d//
//Nl.           .;.           .;;'            '.            :K//
//MK:           .;.          .,,',.           '.           'OW//
//MM0;          .,,..       .''  .,.       ...'.          'kWM//
//MMMK:.          ..'''.....'..   .'..........           ,OWMM//
//MMMMXo.             ..'...        ......             .cKMMMM//
//MMMMMWO:.                                          .,kNMMMMM//
//MMMMMMMNk:.                                      .,xXMMMMMMM//
//MMMMMMMMMNOl'.                                 .ckXMMMMMMMMM//

contract GFly is AccessControl, ERC20, IGFly {
    /// @dev The identifier of the role which maintains other roles.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    /// @dev The identifier of the role which allows accounts to mint tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    uint256 public constant override MAX_SUPPLY = 1e7 * 1 ether;

    IVestedGFly public vestedGFly;

    constructor(address dao, address vestedGFly_) ERC20("gFLY", "GFLY") {
        require(dao != address(0), "GFly:INVALID_ADDRESS");
        require(vestedGFly_ != address(0), "GFly:INVALID_ADDRESS");

        vestedGFly = IVestedGFly(vestedGFly_);

        _setupRole(MINTER_ROLE, dao);
        _setupRole(ADMIN_ROLE, dao);
        _setupRole(ADMIN_ROLE, msg.sender); // This will be surrendered after deployment
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "GFly:MINT_DENIED");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "GFly:ACCESS_DENIED");
        _;
    }

    function mint(address account, uint256 amount) external override onlyMinter {
        require(
            vestedGFly.unminted() + vestedGFly.totalSupply() + totalSupply() + amount <= MAX_SUPPLY,
            "GFly:SUPPLY_OVERFLOW"
        );
        _mint(account, amount);
    }

    function burn(uint256 amount) external override onlyAdmin {
        _burn(msg.sender, amount);
    }

    function addMinter(address minter) external onlyAdmin {
        grantRole(MINTER_ROLE, minter);
    }
}
