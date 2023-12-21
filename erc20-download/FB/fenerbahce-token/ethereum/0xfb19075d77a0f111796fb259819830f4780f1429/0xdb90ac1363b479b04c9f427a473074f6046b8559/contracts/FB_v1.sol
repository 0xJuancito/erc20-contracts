// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Fenerbahçe Token Contract
/// @author Stoken/Paribu

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract FB_v1 is ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable {
    /// @dev Holds blacklisted addresses
    mapping(address => bool) private _blacklist;

    // Minting vars start //
    /// @dev Minting vars to calculate and track minting rounds
    mapping(uint8 => uint256) private _mintingDates;
    mapping(uint8 => uint256) private _mintingAmounts;
    uint8 private _latestMintRound;
    uint256 private _remainingMintingAmount;
    // Minting vars end //

    // Locking vars start //
    /// @dev Locking vars to calculate and track locking
    address private _presaleLocked;
    uint256 private _nextUnlockAt;
    uint256 private _lastUnlockAt;
    uint8 private _latestUnlockRound;
    uint256 private _presaleLockedAmount;
    // Locking vars end //

    /// @dev Minter address
    address private _minter;
    /// @dev Address to mint tokens for
    address private _mintingAddress;

    modifier onlyMinter() {
        require(msg.sender == _minter, "Only minter is allowed to call");
        _;
    }

    /// @dev Initializes contract, set presale locked amounts, setup minting and lock logic
    /// @param name Name of the contract
    /// @param symbol Symbol of the contract
    /// @param mintingAddress Address to mint tokens
    /// @param presaleLocked Address to hold locked presale address
    /// @param minter Minter address
    /// @param address1 Mint address 1
    /// @param address2 Mint address 2
    /// @param address3 Mint address 3
    /// @param address4 Mint address 4
    /// @param address5 Mint address 5
    function initialize(
        string memory name,
        string memory symbol,
        address mintingAddress,
        address presaleLocked,
        address minter,
        address address1,
        address address2,
        address address3,
        address address4,
        address address5
    ) external initializer {
        __ERC20_init(name, symbol);
        __Ownable_init_unchained();
        __Pausable_init_unchained();

        _presaleLockedAmount = 20000000 * 1e6;

        _mintingAddress = mintingAddress;
        _minter = minter;
        _presaleLocked = presaleLocked;

        setupLocks();
        setupMintingRounds();

        _mint(address1, 1700000 * 1e6);
        _mint(address2, 1750000 * 1e6);
        _mint(address3, 1800000 * 1e6);
        _mint(address4, 1200000 * 1e6);
        _mint(address5, 2180000 * 1e6);
    }

    /// @dev Returns token decimals
    /// @return uint8
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @dev Burns tokens, callable only by the owner
    /// @return bool
    function burn(uint256 amount) external onlyOwner returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /// @dev Adds an address to blacklist
    /// @return bool
    function blacklist(address account) external onlyOwner returns (bool) {
        _blacklist[account] = true;
        return true;
    }

    /// @dev Removes an address from blacklist
    /// @return bool
    function unblacklist(address account) external onlyOwner returns (bool) {
        delete _blacklist[account];
        return true;
    }

    /// @dev Checks if an address is blacklisted
    /// @return bool
    function blacklisted(address account) external view virtual returns (bool) {
        return _blacklist[account];
    }

    /// @dev Pauses token transfers
    /// @return bool
    function pause() external onlyOwner whenNotPaused returns (bool) {
        _pause();
        return true;
    }

    /// @dev Unpauses token transfers
    /// @return bool
    function unpause() external onlyOwner whenPaused returns (bool) {
        _unpause();
        return true;
    }

    /// @dev Returns presale locked amount
    /// @return uint256
    function presaleLockedAmount() external view returns (uint256) {
        return _presaleLockedAmount;
    }

    /// @dev Returns remaining minting amount
    /// @return uint256
    function remainingMintingAmount() external view returns (uint256) {
        return _remainingMintingAmount;
    }

    /// @dev Returns next minting round
    /// @return uint8
    function currentMintRound() internal view returns (uint8) {
        return _latestMintRound + 1;
    }

    /// @dev Mints next round tokens, callable only by the owner
    function mint() external onlyMinter {
        require(_mintingDates[currentMintRound()] < block.timestamp, "Too early to mint next round");
        require(_latestMintRound < 73, "Minting is over");
        _mint(_mintingAddress, _mintingAmounts[currentMintRound()]);
        _remainingMintingAmount -= _mintingAmounts[currentMintRound()];
        _latestMintRound++;
    }

    /// @dev Changes minting address, callable only by current minting address
    /// @param newAddress New minting address
    function changeMintingAddress(address newAddress) external {
        require(_mintingAddress == msg.sender, "Can not change address");

        _mintingAddress = newAddress;
    }

    /// @dev Changes minter, callable only by the owner
    /// @param newAddress New minter address
    function changeMinter(address newAddress) external onlyOwner {
        _minter = newAddress;
    }

    /// @dev Returns minting address
    /// @return address
    function mintingAddress() external view returns (address) {
        return _mintingAddress;
    }

    /// @dev Returns minter
    /// @return address
    function minter() external view returns (address) {
        return _minter;
    }

    /// @dev Setups minting rounds, will be called only on initialization
    function setupMintingRounds() internal {
        uint256 nextMintingAt = 1631722020; // 15 Sep 2021 19:07:00
        for (uint8 i = 1; i <= 73; i++) {
            _mintingDates[i] = nextMintingAt;
            nextMintingAt += 30 days;

            if (i < 53 && (i + 4) % 12 != 0) {
                // mints for marketing & tech
                uint256 mintingAmount = i <= 17 ? 938959 * 1e6 : 938958 * 1e6;
                _mintingAmounts[i] = mintingAmount;
                _remainingMintingAmount += mintingAmount;
                continue;
            }

            // mints for treasury
            _mintingAmounts[i] = 4680000 * 1e6;
            _remainingMintingAmount += 4680000 * 1e6;
        }
    }

    /// @dev Setups next and last unlock date and mints presale locks, will be called only on initialization
    function setupLocks() internal {
        _nextUnlockAt = 1652630820; // 15 May 2022 19:07:00
        _lastUnlockAt = _nextUnlockAt + 420 days;
        _mint(_presaleLocked, _presaleLockedAmount);
    }

    /// @dev Setups next and last unlock date and mints presale locks, will be called only on initialization
    /// @param from Address to check locked amount
    /// @param amount To check if sent amount available for presale account
    function checkLockedAmount(address from, uint256 amount) internal {
        // checks locked account on every transfer and decrease locked amount if conditions met
        if (from == _presaleLocked && _presaleLockedAmount > 0) {
            // runs a while loop to update locked amount
            while (_nextUnlockAt <= block.timestamp && _nextUnlockAt <= _lastUnlockAt) {
                _latestUnlockRound++;
                uint256 unlockAmount = _latestUnlockRound <= 5 ? 1333334 * 1e6 : 1333333 * 1e6;

                // increases next unlock timestamp for 30 days
                _nextUnlockAt += 30 days;
                _presaleLockedAmount -= unlockAmount;
            }

            // reverts transaction if available balance is insufficient
            require(balanceOf(from) >= amount + _presaleLockedAmount, "insufficient funds");
        }
    }

    /** @dev Standard ERC20 hook,
        checks if transfer paused,
        checks from or to addresses is blacklisted
        checks available balance if from address is presaleLocked address
    */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        require(!paused(), "ERC20Pausable: token transfer while paused");
        require(!_blacklist[from], "Token transfer from blacklisted address");
        require(!_blacklist[to], "Token transfer to blacklisted address");

        checkLockedAmount(from, amount);
    }
}
