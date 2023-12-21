pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/** @title Pika
    @notice Pika token contract
 */
contract Pika is AccessControl, ERC20 {
    /// @dev The identifier of the role which allows accounts to mint tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address beneficiary,
        address gov
    ) ERC20(name, symbol) {
        // We are minting initialSupply number of tokens
        _mint(beneficiary, totalSupply);
        // Set default admin role: it will be able to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, gov);
    }

    /// @dev A modifier which checks that the caller has the minter role.
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "PIKA: only minter");
        _;
    }

    /// @dev Mints tokens to a recipient.
    ///
    /// This function reverts if the caller does not have the minter role.
    function mint(address _recipient, uint256 _amount) external onlyMinter {
        _mint(_recipient, _amount);
    }

    /// @dev Burns tokens for sender.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}