//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./extensions/TokensRescuer.sol";

error IncorrectArray();
error IncorrectAmount();
error IncorrectAddress();
error IncorrectBounds();
error IncorrectCategory();
error IncorrectSupply();

contract Plx is ERC20Upgradeable, TokensRescuer, AccessControlUpgradeable {
    struct Category {
        uint32 start;
        uint32 end;
        address recipient;
        uint256 totalSupply;
    }

    mapping(uint256 => Category) public tokenomics;
    mapping(uint256 => uint256) public mintedByTokenomic;

    uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18;

    bytes32 public constant MINTER_ROLE = bytes32("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = bytes32("BURNER_ROLE");

    /**
     *  @notice Initializes the contract.
     *  @param name_ token name
     *  @param symbol_ token symbol
     *  @param tokenomicCategories categories of tokenomic
     */
    function __Plx_init(
        string memory name_,
        string memory symbol_,
        Category[] memory tokenomicCategories
    ) external initializer {
        __ERC20_init_unchained(name_, symbol_);
        __Plx_init_unchained(tokenomicCategories);
    }

    /**
     * @dev Mint tokens for the specified categories.
     *
     * This function allows the designated role (MINTER_ROLE) to mint tokens
     * for multiple categories based on their specific tokenomics.
     *
     * Requirements:
     * - The caller must have the MINTER_ROLE.
     * - The provided categoryIds must be valid and correspond to existing
     *   tokenomics.
     *
     * @param categoryIds An array of uint256 values representing the unique
     *                    identifiers of the categories.
     *
     * @notice The function calculates the amount of tokens to be minted for
     *         each category based on its tokenomics parameters.
     * @notice Tokens can only be minted during the period between the 'start'
     *         and 'end' timestamps specified for each category.
     * @notice If the 'end' timestamp is not set (equals 0), the category is
     *         considered invalid, and the minting will revert.
     */
    function mint(uint256[] memory categoryIds) external onlyRole(MINTER_ROLE) {
        for (uint256 i = 0; i < categoryIds.length; ++i) {
            uint256 minted = mintedByTokenomic[categoryIds[i]];
            Category memory category = tokenomics[categoryIds[i]];

            if (category.end == 0) {
                revert IncorrectCategory();
            }

            if (category.start > block.timestamp) {
                continue;
            }

            uint256 amount;
            if (block.timestamp >= category.end) {
                amount = category.totalSupply - minted;
            } else {
                amount =
                    (((block.timestamp - category.start) *
                        category.totalSupply) /
                        (category.end - category.start)) -
                    minted;
            }

            if (amount > 0) {
                mintedByTokenomic[categoryIds[i]] = minted + amount;

                _mint(category.recipient, amount);
            }
        }
    }

    function burn(uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(msg.sender, amount);
    }

    /// @inheritdoc ITokensRescuer
    function rescueERC20Token(
        address token,
        uint256 amount,
        address receiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rescueERC20Token(token, amount, receiver);
    }

    /// @inheritdoc ITokensRescuer
    function rescueNativeToken(
        uint256 amount,
        address receiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rescueNativeToken(amount, receiver);
    }

    /**
     * @dev Initialize the contract with tokenomics categories.
     *
     * This internal function is used during the contract initialization phase to
     * set up the tokenomics categories and roles for the contract creator.
     *
     * Requirements:
     * - The function can only be called during the initialization phase.
     * - At least one tokenomics category must be provided.
     * - The sum of total supplies across all tokenomics categories must equal
     *   `MAX_TOTAL_SUPPLY`.
     * - Each tokenomics category must have valid start and end timestamps, with
     *   `start` being strictly less than `end`.
     * - The `totalSupply` of each tokenomics category must be greater than zero.
     *
     * @param tokenomicCategories An array of `Category` structs representing the
     *                             tokenomics parameters for different categories.
     *
     * @notice It checks the validity of each tokenomics category and sets up the
     *         `tokenomics` mapping accordingly.
     * @notice The `start` and `end` timestamps of each category are updated to be
     *         relative to the current block timestamp.
     * @notice The `totalSupply` of each category is checked, and the sum of total
     *         supplies is verified to be equal to `MAX_TOTAL_SUPPLY`.
     */

    function __Plx_init_unchained(
        Category[] memory tokenomicCategories
    ) internal onlyInitializing {
        if (tokenomicCategories.length == 0) {
            revert IncorrectArray();
        }


        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);

        uint256 totalSupplyToCheck;
        for (uint256 i = 0; i < tokenomicCategories.length; ++i) {
            Category memory tokenomicsCategory = tokenomicCategories[i];

            if (tokenomicsCategory.start >= tokenomicsCategory.end) {
                revert IncorrectBounds();
            }

            if (tokenomicsCategory.totalSupply == 0) {
                revert IncorrectAmount();
            }

            if (tokenomicsCategory.recipient == address(0)) {
                revert IncorrectAddress();
            }

            tokenomicsCategory.start += uint32(block.timestamp);
            tokenomicsCategory.end += uint32(block.timestamp);

            tokenomics[i] = tokenomicsCategory;

            totalSupplyToCheck += tokenomicsCategory.totalSupply;
        }

        if (totalSupplyToCheck != MAX_TOTAL_SUPPLY) {
            revert IncorrectSupply();
        }
    }
}
