//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./shared/ERC20Upgradeable.sol";
import "./shared/Interfaces.sol";
import "./shared/MintMath.sol";

contract PurposeV1 is ERC20Upgradeable, UUPSUpgradeable, IPurpose {
    event Burned(uint256 amount, bytes32[] hodlKeys, bytes data);

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDubi private immutable _dubi;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IHodl private immutable _hodl;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address dubi,
        address hodl,
        address externalAddress1,
        address externalAddress2,
        address externalAddress3,
        address externalAddress4,
        address trustedForwarder
    )
        ERC20Upgradeable(
            externalAddress1,
            externalAddress2,
            externalAddress3,
            externalAddress4,
            trustedForwarder
        )
    {
        require(
            dubi != address(0) || hodl != address(0),
            "PRPS_V1: bad initialize"
        );

        _dubi = IDubi(dubi);
        _hodl = IHodl(hodl);
    }

    struct UnpackedBalance {
        uint96 balance;
        uint96 hodlBalance;
        uint64 __reserved;
    }

    function initialize() public initializer {
        __ERC20_init_unchained("Purpose", "PRPS");
    }

    function balanceOf(address tokenHolder)
        public
        view
        override
        returns (uint256)
    {
        return uint96(_balances[tokenHolder]);
    }

    function hodlBalanceOf(address tokenHolder) public view returns (uint256) {
        return uint96(_balances[tokenHolder] >> 96);
    }

    function mint(address account, uint96 amount) public onlyOwner {
        require(account != address(0), "PRPS_V1: mint to zero address");

        _beforeTokenTransfer(address(0), account, amount);

        UnpackedBalance memory unpacked = _unpackBalance(_balances[account]);
        unpacked.balance += amount;

        _totalSupply += amount;
        _balances[account] = _packBalance(unpacked);

        emit Transfer(address(0), account, amount);
    }

    function burn(
        uint96 amount,
        bytes32[] calldata hodlKeys,
        bytes calldata data
    ) public {
        address account = _msgSender();

        require(account != address(0), "PRPS_V1: burn from zero address");

        _beforeTokenTransfer(account, address(0), amount);

        UnpackedBalance memory unpacked = _unpackBalance(_balances[account]);

        uint96 totalDubiToMint;

        // 1) Try to burn unlocked PRPS
        uint96 lockedPrpsToBurn = amount;
        uint96 burnableUnlockedPrps = unpacked.balance;

        // Catch underflow i.e. don't burn more than we need to
        if (burnableUnlockedPrps > amount) {
            burnableUnlockedPrps = amount;
        }

        // Calculate DUBI to mint based on unlocked PRPS we can burn
        totalDubiToMint = MintMath.calculateDubiToMintMax(burnableUnlockedPrps);
        lockedPrpsToBurn -= burnableUnlockedPrps;

        // 2) Burn locked PRPS if there's not enough unlocked PRPS
        if (lockedPrpsToBurn > 0) {
            require(
                unpacked.hodlBalance >= lockedPrpsToBurn,
                "PRPS_V1: insufficient locked"
            );
            require(hodlKeys.length > 0, "PRPS_V1: no hodl keys provided");
            unpacked.hodlBalance -= lockedPrpsToBurn;

            // Reverts if `lockedPrpsToBurn` does not reach 0
            uint96 dubiToMintFromLockedPrps = _hodl.purposeLockedBurn({
                from: account,
                amount: lockedPrpsToBurn,
                dubiMintTimestamp: uint32(block.timestamp),
                hodlKeys: hodlKeys
            });

            totalDubiToMint += dubiToMintFromLockedPrps;
        }

        // Mint DUBI taking differences between burned locked/unlocked into account
        if (totalDubiToMint > 0) {
            _dubi.purposeMint(account, totalDubiToMint);
        }

        require(
            unpacked.balance >= burnableUnlockedPrps,
            "PRPS_V1: not enough unlocked"
        );
        unchecked {
            unpacked.balance -= burnableUnlockedPrps;
        }

        _totalSupply -= burnableUnlockedPrps;
        _balances[account] = _packBalance(unpacked);

        // The `Burned` event is emitted with the total amount that got burned (i.e. locked PRPS + unlocked PRPS).
        emit Burned(amount, hodlKeys, data);

        // We emit a transfer event with the actual burn amount excluding burned locked PRPS.
        emit Transfer(account, address(0), burnableUnlockedPrps);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "PRPS_V1: transfer from zero");
        require(to != address(0), "PRPS_V1: transfer to zero");
        require(amount <= type(uint96).max, "PRPS_V1: bad amount");

        _beforeTokenTransfer(from, to, amount);

        UnpackedBalance memory unpackedFrom = _unpackBalance(_balances[from]);
        UnpackedBalance memory unpackedTo = unpackedFrom;

        // edge case
        if (from != to) {
            unpackedTo = _unpackBalance(_balances[to]);
        }

        uint96 _amount = uint96(amount);

        require(
            unpackedFrom.balance >= _amount,
            "PRPS_V1: insufficient balance"
        );
        unchecked {
            unpackedFrom.balance -= _amount;
        }

        unpackedTo.balance += _amount;

        // We only need to pack twice if from != to
        if (from != to) {
            _balances[to] = _packBalance(unpackedTo);
        }

        _balances[from] = _packBalance(unpackedFrom);

        emit Transfer(from, to, _amount);
    }

    // helper

    function migrateLockedPrps(address account, uint96 hodlAmount) external {
        require(msg.sender == address(_hodl), "PRPS_V1: bad caller");

        UnpackedBalance memory unpacked = _unpackBalance(_balances[account]);
        unpacked.hodlBalance += hodlAmount;

        _balances[account] = _packBalance(unpacked);
    }

    function lockPrps(
        address from,
        address to,
        uint96 amount
    ) external {
        // NOTE: msg.sender is intentional
        require(msg.sender == address(_hodl), "PRPS_V1: bad caller");
        require(from != address(0), "PRPS_V1: transfer from zero");
        require(to != address(0), "PRPS_V1: transfer to zero");

        UnpackedBalance memory unpackedFrom = _unpackBalance(_balances[from]);
        UnpackedBalance memory unpackedTo = unpackedFrom;

        // edge case
        if (from != to) {
            unpackedTo = _unpackBalance(_balances[to]);
        }

        unpackedFrom.balance -= amount;
        unpackedTo.hodlBalance += amount;

        // Reduce totalSupply by locked amount
        _totalSupply -= amount;

        // We only need to pack twice if from != to
        if (from != to) {
            _balances[to] = _packBalance(unpackedTo);
        }

        _balances[from] = _packBalance(unpackedFrom);
    }

    function unlockPrps(address from, uint96 amount) external {
        // NOTE: msg.sender is intentional
        require(msg.sender == address(_hodl), "PRPS_V1: bad caller");
        require(from != address(0), "PRPS_V1: from is zero ");

        UnpackedBalance memory unpackedFrom = _unpackBalance(_balances[from]);
        unpackedFrom.hodlBalance -= amount;
        unpackedFrom.balance += amount;

        // Increase totalSupply by locked amount
        _totalSupply += amount;

        _balances[from] = _packBalance(unpackedFrom);
    }

    function _unpackBalance(uint256 packedData)
        internal
        pure
        returns (UnpackedBalance memory)
    {
        UnpackedBalance memory unpacked;

        // 1) Read balance from the first 96 bits
        unpacked.balance = uint96(packedData);

        // 2) Read hodlBalance from the next 96 bits
        unpacked.hodlBalance = uint96(packedData >> 96);

        // 3) Read __reserved from the next 64 bits
        unpacked.__reserved = uint64(packedData >> (96 + 96));

        return unpacked;
    }

    function _packBalance(UnpackedBalance memory unpacked)
        internal
        pure
        returns (uint256)
    {
        uint256 packedData;

        // 1) Write balance to the first 96 bits
        packedData |= unpacked.balance;

        // 2) Write hodlBalance to the the next 96 bits
        packedData |= uint256(unpacked.hodlBalance) << 96;

        // 3) Write __reserved to the next 64 bits
        packedData |= uint256(unpacked.__reserved) << (96 + 96);

        return packedData;
    }

    // Upgradability

    function _authorizeUpgrade(address) internal view override onlyOwner {}

    function implementation() public view returns (address) {
        return _getImplementation();
    }
}
