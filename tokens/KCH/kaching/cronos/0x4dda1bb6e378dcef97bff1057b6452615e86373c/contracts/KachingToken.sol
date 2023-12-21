// SPDX-License-Identifier: GPL-2.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
 * @title  Kaching native protocol token
 * @author Kaching team
 * @notice  ERC20 Tokens with initial minting to multiple addresses
 */
contract KachingToken is ERC20Permit {
    /* ============ Global Variables ============ */


    /// @notice ERC20 controlled token decimals.
    uint8 private constant _decimals = 18;

    /* ============ Events ============ */

    /// @dev Emitted for each initial mint Allocation
    event AllocationMinted(address indexed to, uint256 indexed amount);

    /* ============ Structs ============ */

    /// @dev Struct representing one minting address and amount
    struct MintAllocation {
        address to;
        uint256 amount;
    }

    /* ============ Constructor ============ */

    /// @notice Deploy token and allocate initial supply to addresses
    /// @param _mintAllocations Allocations of tokens to mint to addresses
    constructor(
        MintAllocation[] memory _mintAllocations
    ) ERC20Permit("KachingToken") ERC20("Kaching", "KCH") {

        for (uint256 i = 0; i < _mintAllocations.length; i++) {
            MintAllocation memory allocation = _mintAllocations[i];
            require(allocation.to != address(0), "KachingToken/mint-to-not-zero-address");
            _mint(allocation.to, allocation.amount);
            emit AllocationMinted(allocation.to, allocation.amount);
        }

    }

    /* ============ External Functions ============ */

    /// @notice Returns the ERC20 controlled token decimals.
    /// @return uint8 decimals.
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
