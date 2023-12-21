// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./../lib/SafeMath8.sol";
import "./../interfaces/IMultiAssetTreasury.sol";
import "./../interfaces/IDollar.sol";
import "./../ERC20/ERC20Custom.sol";
import "./../Operator.sol";

contract SyntheticAsset is ERC20Custom, IDollar, Operator {
    using SafeMath for uint256;

    // ERC20
    string public symbol;
    string public name;
    uint8 public constant decimals = 18;
    uint256 public constant genesis_supply = 1 ether; // 1 will be minted at genesis for liq pool seeding

    // CONTRACTS
    address public treasury;

    /* ========== MODIFIERS ========== */

    modifier onlyPools() {
        require(IMultiAssetTreasury(treasury).hasPool(msg.sender), "!pools");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(
        string memory _name,
        string memory _symbol,
        address _treasury
    ) public {
        name = _name;
        symbol = _symbol;
        treasury = _treasury;
        _mint(_msgSender(), genesis_supply);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Burn Asset. Can be used by Pool only
    function poolBurnFrom(address _address, uint256 _amount) external override onlyPools {
        burnFrom(_address, _amount);
        emit DollarBurned(_address, msg.sender, _amount);
    }

    // Mint Asset. Can be used by Pool only
    function poolMint(address _address, uint256 _amount) external override onlyPools {
        super._mint(_address, _amount);
        emit DollarMinted(msg.sender, _address, _amount);
    }

    function setTreasuryAddress(address _treasury) public onlyOperator {
        treasury = _treasury;
    }

    /* ========== EVENTS ========== */

    // Track Asset burned
    event DollarBurned(address indexed from, address indexed to, uint256 amount);

    // Track Asset minted
    event DollarMinted(address indexed from, address indexed to, uint256 amount);
}
