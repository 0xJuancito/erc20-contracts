// SPDX-License-Identifier: Not-License
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./extensions/ERC20SupplyControlledToken.sol";
import "./extensions/ERC20MintableToken.sol";
import "./extensions/ERC20BatchTransferableToken.sol";
import "./extensions/ERC20VotesToken.sol";

contract SUPToken is
    Context,
    ERC20Capped,
    AccessControl,
    ERC20Burnable,
    ERC20MintableToken,
    ERC20BatchTransferableToken,
    ERC20Permit,
    ERC20VotesToken,
    ERC20SupplyControlledToken
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(
        address _initialSupplyRecipient
    )
        ERC20SupplyControlledToken(
            "SAKURA UNITED PLATFORM",
            "SUP",
            18,
            1000000000000000000000000000,
            927000000000000000000000000,
            _initialSupplyRecipient
        )
        ERC20Permit("SAKURA UNITED PLATFORM")
    {
        address _initialAdmin = _msgSender();
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(MINTER_ROLE, _initialAdmin);
        _grantRole(BURNER_ROLE, _initialAdmin);
    }

    function decimals()
        public
        view
        virtual
        override(ERC20, ERC20SupplyControlledToken)
        returns (uint8)
    {
        return super.decimals();
    }

    function _mint(
        address account,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Capped, ERC20VotesToken) onlyRole(MINTER_ROLE) {
        super._mint(account, amount);
    }

    function _finishMinting() internal override onlyRole(MINTER_ROLE) {
        super._finishMinting();
    }

    function burn(uint256 amount) public override onlyRole(BURNER_ROLE) {
        super.burn(amount);
    }

    function burnFrom(
        address account,
        uint256 amount
    ) public override onlyRole(BURNER_ROLE) {
        super.burnFrom(account, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20VotesToken)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20VotesToken)
    {
        super._burn(account, amount);
    }
}
