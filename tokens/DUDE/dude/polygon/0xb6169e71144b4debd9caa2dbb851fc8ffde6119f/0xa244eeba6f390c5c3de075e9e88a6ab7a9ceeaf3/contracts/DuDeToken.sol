// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

interface IDudeToken {
    function burn(uint256 count) external;

    function balanceOf(address addr) external returns (uint256);

    function startCoins() external returns (uint256);

    function totalSupply() external returns (uint256);

    function startTime() external returns (uint256);
}

contract BurnWallet is Ownable {
    IDudeToken immutable token;

    uint256 public constant burnPerDay = 10 ** 27;
    uint256 public constant burnHitPoint = 900 * 10 ** 27;
    address public burnTaskAddress;

    constructor(
        address dudeToken_,
        address owner_,
        address burnTaskAddress_
    )
    {
        _transferOwnership(owner_);
        token = IDudeToken(dudeToken_);
        burnTaskAddress = burnTaskAddress_;
    }

    modifier onlyBurnTaskOrOwner() {
        require(
            msg.sender == burnTaskAddress || msg.sender == owner(),
            "BurnWallet: account is not burn task owner or owner"
        );
        _;
    }

    function setBurnTaskAddress(address burnTaskAddress_) external onlyOwner {
        burnTaskAddress = burnTaskAddress_;
    }

    function burn() external onlyBurnTaskOrOwner {

        // days from starting the contract
        uint256 day = (block.timestamp - token.startTime()) / 1 days;

        // burned coin count
        uint256 totalBurn = token.startCoins() - token.totalSupply();

        uint256 dayCapacity = day * burnPerDay - totalBurn;
        uint256 burnWalletBalance = token.balanceOf(address(this));

        require(burnWalletBalance > 0, "BurnWallet: balance is not positive");

        require(dayCapacity > 0, "BurnWallet: day burn limit exceed");

        // the burn amount
        uint256 toBurn = Math.min(burnWalletBalance, dayCapacity);

        // checking if a 900 billion is already burned
        require(totalBurn < burnHitPoint, "BurnWallet: total burn amount exceed");

        toBurn = Math.min(toBurn, burnHitPoint - totalBurn);

        token.burn(toBurn);
    }
}


contract DuDeToken is ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable {

    // freeze accounts mapping
    mapping(address => bool) public frozen;

    // burn wallet contract
    BurnWallet public burnWallet;

    uint256 public constant startCoins = 10 ** 30;

    uint256 public startTime;

    function initialize(
        string memory name_, 
        string memory symbol_,
        address burnTaskAddress_
    )
    public initializer 
    {
        __Context_init();
        __Ownable_init();
        __Pausable_init();
        __ERC20_init(name_, symbol_);

        // minting starting coins
        _mint(address(this), startCoins);

        burnWallet = new BurnWallet(address(this), owner(), burnTaskAddress_);

        startTime = block.timestamp;
    }

    function freeze(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; ++i) {
            require(accounts[i] != address(0), "DuDeToken: null address should not be in this list");
            frozen[accounts[i]] = true;
        }
    }

    function unFreeze(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; ++i) {
            frozen[accounts[i]] = false;
        }
    }


    // modifier to give access on some actions only not freezed accounts
    modifier whenNotFrozen(address from, address to) {
        require(frozen[from] == false && frozen[to] == false, "DuDeToken: account is frozen");
        _;
    }

    modifier onlyBurnWallet() {
        require(msg.sender == address(burnWallet), "DuDeToken: address does not have burn access");
        _;
    }

    function burn(uint256 count) external whenNotPaused onlyBurnWallet {
        _burn(msg.sender, count);
    }

    function airdrop(address[] calldata accounts, uint256[] calldata counts) external whenNotPaused onlyOwner {
        require(accounts.length == counts.length, "DuDeToken: invalid Data lengths mismatch");

        for (uint256 i = 0; i < accounts.length; ++i) {
            require(accounts[i] != address(0), "DuDeToken: zero address included");
            _transfer(address(this), accounts[i], counts[i]);
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    whenNotFrozen(from, to)
    whenNotPaused
    override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}
