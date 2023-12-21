// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import "../interfaces/IAnkrBond_R1.sol";
import "../interfaces/ICertToken.sol";
import "../interfaces/IOwnable.sol";

contract aFTMc_R3 is OwnableUpgradeable, ERC165Upgradeable, ERC20Upgradeable, ICertToken {
    /**
     * Variables
     */

    address public pool;
    address public bondToken; // also known as aFTMb

    /**
     * Modifiers
     */

    modifier onlyMinter() {
        require(
           msg.sender == pool ||
           msg.sender == bondToken,
           "onlyMinter: not allowed"
        );
        _;
    }

    function initialize(address fantomPool, address _bondToken) public initializer {
        __Ownable_init();
        __ERC20_init_unchained("Ankr FTM Reward Bearing Certificate", "aFTMc");
        pool = fantomPool;
        bondToken = _bondToken;
        uint256 initSupply = IAnkrBond_R1(bondToken).totalSharesSupply();
        // mint init supply if not inizialized
        super._mint(address(bondToken), initSupply);
    }

    function bondTransferTo(address account, uint256 amount) external override onlyMinter {
        super._transfer(address(bondToken), account, amount);
    }

    function bondTransferFrom(address account, uint256 amount) external override onlyMinter {
        super._transfer(account, address(bondToken), amount);
    }

    function ratio() public view returns (uint256) {
        return IAnkrBond_R1(bondToken).ratio();
    }

    function burn(address account, uint256 amount) external override onlyMinter {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external override onlyMinter {
        _mint(account, amount);
    }

    function changePoolContract(address newPool) external override onlyOwner {
        address oldPool = pool;
        pool = newPool;
        emit PoolContractChanged(oldPool, newPool);
    }

    function changeBondToken(address newBondToken) external override onlyOwner {
        address oldBondToken = bondToken;
        bondToken = newBondToken;
        emit BondTokenChanged(oldBondToken, newBondToken);
    }

    function balanceWithRewardsOf(address account) public view returns (uint256) {
        uint256 shares = this.balanceOf(account);
        return IAnkrBond_R1(bondToken).sharesToBalance(shares);
    }

    function isRebasing() public pure returns (bool) {
        return false;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId)
        || interfaceId == type(IOwnable).interfaceId
        || interfaceId == type(ICertToken).interfaceId;
    }

    function name() public pure override(ERC20Upgradeable) returns (string memory) {
        return "Ankr Staked FTM";
    }

    function symbol() public pure override(ERC20Upgradeable) returns (string memory) {
        return "ankrFTM";
    }
}
