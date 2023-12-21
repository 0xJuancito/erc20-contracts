// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import "./interfaces/IBaseTokenLogic.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract BaseTokenLogic is
    ERC20Upgradeable,
    Ownable2StepUpgradeable,
    IBaseTokenLogic
{
    /*************
     * CONSTANTS *
     *************/

    // J : トークンの最大供給量
    // E : the maximum supply of this token
    uint256 private _maxSupply;

    /*************
     * FUNCTIONS *
     *************/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev mint
     *
     * NOTE : onlyOwner
     * NOTE : _totalSupply have to be equal to or smaller than _maxSupply
     *
     * @param account address
     * @param amount  uint256
     */
    function mint(address account, uint256 amount) external onlyOwner {
        require(
            amount + totalSupply() <= _maxSupply,
            "Cannot exceed _maxSupply."
        );
        require(amount > 0, "minting amount have to be positive");
        _mint(account, amount);
    }

    /**
     * @dev burn
     *
     * @param amount  uint256
     */
    function burn(uint256 amount) external onlyOwner {
        require(amount > 0, "amount have to be positive");
        _burn(msg.sender, amount);
    }

    /**
     * @dev get max supply
     */
    function maxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev J : Ownershipをrenounceできなくする
     * @dev E : make ownership cannot be renounced
     *
     * NOTE : ownership should not be renounced.
     *
     */
    function renounceOwnership() public pure override {
        revert("cannot be renounced!");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
