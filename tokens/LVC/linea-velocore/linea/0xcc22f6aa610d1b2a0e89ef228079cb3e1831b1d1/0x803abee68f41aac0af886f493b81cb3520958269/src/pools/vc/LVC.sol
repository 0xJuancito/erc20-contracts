// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../PoolWithLPToken.sol";
import "src/lib/RPow.sol";
import "src/interfaces/IVC.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../SatelliteUpgradeable.sol";

/**
 * @dev The emission token of Velocore.
 *
 * implemented as a pool. VC is its "LP" token.
 * - takes old version of VC token and gives the same amount of new VC token.
 * - when called by vault, emits VC on an exponentially decaying schedule
 *
 */

contract LVC is IVC, PoolWithLPToken, ISwap, SatelliteUpgradeable {
    uint256 constant DECAY = 999999983382381333; // (0.99)^(1/(seconds in a week)) * 1e18
    uint256 constant START = 1692874800;
    uint256 constant INITIAL_SUPPLY = 100_000_000e18;

    event Migrated(address indexed user, uint256 amount);

    using TokenLib for Token;
    using SafeCast for uint256;
    using SafeCast for int256;

    uint128 _totalSupply;
    uint128 lastEmission;

    Token immutable oldVC;
    address immutable veVC;
    bool initialized;
    bool initialMint;

    constructor(address selfAddr, IVault vault_, Token oldVC_, address veVC_) Pool(vault_, selfAddr, address(this)) {
        oldVC = oldVC_;
        veVC = veVC_;
    }

    function totalSupply() public view override(IERC20, PoolWithLPToken) returns (uint256) {
        return _totalSupply;
    }

    function initialize() external {
        if (!initialized) {
            lastEmission = uint128(block.timestamp);
            PoolWithLPToken._initialize("Linea Velocore", "LVC");
            initialized = true;
        }
    }

    /**
     * the emission schedule depends on total supply of veVC + VC.
     * therefore, on veVC migration, this function should be called to nofity the change.
     */
    function notifyMigration(uint128 n) external {
        require(msg.sender == veVC);
        _totalSupply += n;
        _balanceOf[address(vault)] += n; // mint vc to the vault to simulate vc locking.
        _simulateMint(n);
    }

    /**
     * called by the vault.
     * (maxSupply - mintedSupply) decays 1% by every week.
     * @return newlyMinted amount of VCs to be distributed to gauges
     */
    function dispense() external onlyVault returns (uint256) {
        unchecked {
            uint256 emitted;

            if (lastEmission < START) {
                lastEmission = uint128(Math.min(block.timestamp, START));
            }
            if (lastEmission == block.timestamp) return 0;

            if (_totalSupply < 200_000_000e18) {
                uint256 decay1e18 = 1e18 - rpow(DECAY, block.timestamp - lastEmission, 1e18);
                emitted = (decay1e18 * (300_000_000 * 1e18 - _totalSupply)) / 1e18;
            } else {
                emitted = 0.16534391534e18 * (block.timestamp - lastEmission);
            }

            lastEmission = uint128(block.timestamp);
            _totalSupply += uint128(emitted);
            _simulateMint(emitted);
            return emitted;
        }
    }

    /**
     * VC emission rate per second
     */
    function emissionRate() external view override returns (uint256) {
        if (_totalSupply >= 200_000_000 * 1e18) return 0.16534391534e18;
        if (block.timestamp < START) return 0;
        uint256 a = ((300_000_0001e18 - _totalSupply) * rpow(DECAY, block.timestamp - lastEmission, 1e18)) / 1e18;

        return a - ((a * DECAY) / 1e18);
    }

    function velocore__execute(address user, Token[] calldata tokens, int128[] memory r, bytes calldata)
        external
        onlyVault
        returns (int128[] memory, int128[] memory)
    {
        require(!initialMint && user == address(uint160(uint256(_readVaultStorage(SSLOT_HYPERCORE_TREASURY)))));
        require(tokens.length == 1 && tokens[0] == toToken(this));

        initialMint = true;
        r[0] = -INITIAL_SUPPLY.toInt256().toInt128();
        _totalSupply += uint128(INITIAL_SUPPLY);
        return (new int128[](1), r);
    }

    function swapType() external view override returns (string memory) {
        return "VC";
    }

    function listedTokens() external view override returns (Token[] memory ret) {
        ret = new Token[](1);
        ret[0] = oldVC;
    }

    function lpTokens() external view override returns (Token[] memory ret) {
        ret = new Token[](1);
        ret[0] = toToken(this);
    }

    function underlyingTokens(Token lp) external view override returns (Token[] memory) {
        return new Token[](0);
    }
}
