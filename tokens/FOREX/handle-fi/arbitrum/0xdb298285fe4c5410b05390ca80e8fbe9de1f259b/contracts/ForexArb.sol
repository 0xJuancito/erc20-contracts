// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./Forex.sol";
import "./interfaces/IArbToken.sol";

/*                                                *\
 *                ,.-"""-.,                       *
 *               /   ===   \                      *
 *              /  =======  \                     *
 *           __|  (o)   (0)  |__                  *
 *          / _|    .---.    |_ \                 *
 *         | /.----/ O O \----.\ |                *
 *          \/     |     |     \/                 *
 *          |                   |                 *
 *          |                   |                 *
 *          |                   |                 *
 *          _\   -.,_____,.-   /_                 *
 *      ,.-"  "-.,_________,.-"  "-.,             *
 *     /          |       |  ╭-╮     \            *
 *    |           l.     .l  ┃ ┃      |           *
 *    |            |     |   ┃ ╰━━╮   |           *
 *    l.           |     |   ┃ ╭╮ ┃  .l           *
 *     |           l.   .l   ┃ ┃┃ ┃  | \,         *
 *     l.           |   |    ╰-╯╰-╯ .l   \,       *
 *      |           |   |           |      \,     *
 *      l.          |   |          .l        |    *
 *       |          |   |          |         |    *
 *       |          |---|          |         |    *
 *       |          |   |          |         |    *
 *       /"-.,__,.-"\   /"-.,__,.-"\"-.,_,.-"\    *
 *      |            \ /            |         |   *
 *      |             |             |         |   *
 *       \__|__|__|__/ \__|__|__|__/ \_|__|__/    *
\*                                                 */

contract ForexArb is Forex, IArbToken {
    address public immutable override l1Address;
    address public l2Gateway;

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "FOREX: caller not an admin");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address l1Address_,
        address l2Gateway_
    ) Forex(name_, symbol_) {
        assert(l1Address_ != address(0));
        assert(l2Gateway_ != address(0));
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        l1Address = l1Address_;
        l2Gateway = l2Gateway_;
        grantRole(OPERATOR_ROLE, l2Gateway_);
    }

    function bridgeMint(address account, uint256 amount)
        external
        override
        onlyOperator
    {
        _mint(account, amount);
    }

    function bridgeBurn(address account, uint256 amount)
        external
        override
        onlyOperator
    {
        _burn(account, amount);
    }

    function setL2Gateway(address _l2Gateway) external onlyAdmin {
        assert(_l2Gateway != address(0));
        revokeRole(OPERATOR_ROLE, l2Gateway);
        l2Gateway = _l2Gateway;
        grantRole(OPERATOR_ROLE, l2Gateway);
    }
}
