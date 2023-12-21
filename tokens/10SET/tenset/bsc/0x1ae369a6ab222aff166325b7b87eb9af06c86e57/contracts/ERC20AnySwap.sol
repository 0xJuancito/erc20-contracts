// SPDX-License-Identifier: MIT
// Based on https://github.com/anyswap/chaindata/blob/3d4640fdfde46e4c34eed84efbb06ab5ea69e88d/AnyswapV6ERC20.sol

pragma solidity 0.8.10;

import { ERC20Fee } from "./ERC20Fee.sol";

contract ERC20AnySwap is ERC20Fee {
    /*///////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) ERC20Fee(_owner) {
        _init = true;
        vault = _owner;
        pendingVault = _owner;
    }

    /*///////////////////////////////////////////////////////////////
                              ANYSWAP STORAGE
    //////////////////////////////////////////////////////////////*/

    // init flag for setting immediate vault, needed for CREATE2 support
    bool private _init;

    // flag to enable/disable swapout vs vault.burn so multiple events are triggered
    bool private _vaultOnly;

    // configurable delay for timelock functions
    uint256 public constant delay = 2 * 24 * 3600;

    // set of minters, can be this bridge or other bridges
    mapping(address => bool) public isMinter;
    address[] public minters;

    // primary controller of the token contract
    address public vault;

    address public pendingMinter;
    uint256 public delayMinter;

    address public pendingVault;
    uint256 public delayVault;

    /*///////////////////////////////////////////////////////////////
                              ANYSWAP EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogChangeVault(address indexed oldVault, address indexed newVault, uint256 indexed effectiveTime);
    event LogSwapin(bytes32 indexed txhash, address indexed account, uint256 amount);
    event LogSwapout(address indexed account, address indexed bindaddr, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                              ANYSWAP LOGIC
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuth() {
        require(isMinter[msg.sender], "AnyswapV4ERC20: FORBIDDEN");
        _;
    }

    modifier onlyVault() {
        require(msg.sender == mpc(), "AnyswapV3ERC20: FORBIDDEN");
        _;
    }

    function mpc() public view returns (address) {
        if (block.timestamp >= delayVault) {
            return pendingVault;
        }
        return vault;
    }

    function setVaultOnly(bool enabled) external onlyVault {
        _vaultOnly = enabled;
    }

    function initVault(address _vault) external onlyVault {
        require(_init, "Anyswap: Vault already initialized");
        vault = _vault;
        pendingVault = _vault;
        isMinter[_vault] = true;
        minters.push(_vault);
        delayVault = block.timestamp;
        _init = false;
    }

    function setVault(address _vault) external onlyVault {
        require(_vault != address(0), "AnyswapV3ERC20: address(0x0)");
        pendingVault = _vault;
        delayVault = block.timestamp + delay;
    }

    function applyVault() external onlyVault {
        require(block.timestamp >= delayVault, "Anyswap: Vault delay not met");
        vault = pendingVault;
    }

    function setMinter(address _auth) external onlyVault {
        require(_auth != address(0), "AnyswapV3ERC20: address(0x0)");
        pendingMinter = _auth;
        delayMinter = block.timestamp + delay;
    }

    function applyMinter() external onlyVault {
        require(block.timestamp >= delayMinter, "Anyswap: Minter delay not met");
        isMinter[pendingMinter] = true;
        minters.push(pendingMinter);
    }

    // No time delay revoke minter emergency function
    function revokeMinter(address _auth) external onlyVault {
        isMinter[_auth] = false;
    }

    function getAllMinters() external view returns (address[] memory) {
        return minters;
    }

    function changeVault(address newVault) external onlyVault returns (bool) {
        require(newVault != address(0), "AnyswapV3ERC20: address(0x0)");
        vault = newVault;
        pendingVault = newVault;
        emit LogChangeVault(vault, pendingVault, block.timestamp);
        return true;
    }

    event AnyswapMint(address indexed account, uint256 amount);
    function mint(address to, uint256 amount) external onlyAuth returns (bool) {
        _mint(to, amount);
        emit AnyswapMint(to, amount);
        return true;
    }

    event AnyswapBurn(address indexed account, uint256 amount);
    function burn(address from, uint256 amount) external onlyAuth returns (bool) {
        require(from != address(0), "AnyswapV3ERC20: address(0x0)");
        _burn(from, amount);
        emit AnyswapBurn(from, amount);
        return true;
    }

    function Swapin(
        bytes32 txhash,
        address account,
        uint256 amount
    ) external onlyAuth returns (bool) {
        _mint(account, amount);
        emit LogSwapin(txhash, account, amount);
        return true;
    }

    function Swapout(uint256 amount, address bindaddr) external returns (bool) {
        require(!_vaultOnly, "AnyswapV4ERC20: onlyAuth");
        require(bindaddr != address(0), "AnyswapV3ERC20: address(0x0)");
        _burn(msg.sender, amount);
        emit LogSwapout(msg.sender, bindaddr, amount);
        return true;
    }
}
