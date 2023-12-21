// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "src/interfaces/IAuthorizer.sol";
import "src/interfaces/IFacet.sol";
import "src/interfaces/IGauge.sol";
import "src/interfaces/IConverter.sol";
import "src/interfaces/IBribe.sol";
import "src/interfaces/ISwap.sol";
import "src/lib/Token.sol";

bytes32 constant SSLOT_HYPERCORE_TREASURY = bytes32(uint256(keccak256("hypercore.treasury")) - 1);
bytes32 constant SSLOT_HYPERCORE_AUTHORIZER = bytes32(uint256(keccak256("hypercore.authorizer")) - 1);
bytes32 constant SSLOT_HYPERCORE_ROUTINGTABLE = bytes32(uint256(keccak256("hypercore.routingTable")) - 1);
bytes32 constant SSLOT_HYPERCORE_POOLBALANCES = bytes32(uint256(keccak256("hypercore.poolBalances")) - 1);
bytes32 constant SSLOT_HYPERCORE_USERBALANCES = bytes32(uint256(keccak256("hypercore.userBalances")) - 1);
bytes32 constant SSLOT_HYPERCORE_EMISSIONINFORMATION = bytes32(uint256(keccak256("hypercore.emissionInformation")) - 1);
bytes32 constant SSLOT_REENTRACNYGUARD_LOCKED = bytes32(uint256(keccak256("ReentrancyGuard.locked")) - 1);
bytes32 constant SSLOT_PAUSABLE_PAUSED = bytes32(uint256(keccak256("Pausable.paused")) - 1);

struct VelocoreOperation {
    bytes32 poolId;
    bytes32[] tokenInformations;
    bytes data;
}

interface IVault {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
    event Swap(ISwap indexed pool, address indexed user, Token[] tokenRef, int128[] delta);
    event Gauge(IGauge indexed pool, address indexed user, Token[] tokenRef, int128[] delta);
    event Convert(IConverter indexed pool, address indexed user, Token[] tokenRef, int128[] delta);
    event Vote(IGauge indexed pool, address indexed user, int256 voteDelta);
    event UserBalance(address indexed to, address indexed from, Token[] tokenRef, int128[] delta);
    event BribeAttached(IGauge indexed gauge, IBribe indexed bribe);
    event BribeKilled(IGauge indexed gauge, IBribe indexed bribe);
    event GaugeKilled(IGauge indexed gauge, bool killed);

    function notifyInitialSupply(Token, uint128, uint128) external;
    function attachBribe(IGauge gauge, IBribe bribe) external;
    function killBribe(IGauge gauge, IBribe bribe) external;
    function killGauge(IGauge gauge, bool t) external;
    function ballotToken() external returns (Token);
    function emissionToken() external returns (Token);
    function execute(Token[] calldata tokenRef, int128[] memory deposit, VelocoreOperation[] calldata ops)
        external
        payable;

    function facets() external view returns (Facet[] memory facets_);
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);
    function facetAddresses() external view returns (address[] memory facetAddresses_);
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);

    function query(address user, Token[] calldata tokenRef, int128[] memory deposit, VelocoreOperation[] calldata ops)
        external
        returns (int128[] memory);

    function admin_setFunctions(address implementation, bytes4[] calldata sigs) external;
    function admin_addFacet(IFacet implementation) external;
    function admin_setAuthorizer(IAuthorizer auth_) external;

    function admin_pause(bool t) external;
    function admin_setTreasury(address treasury) external;
    function inspect(address lens, bytes memory data) external;

    function factory() external view returns (address);
    function lens() external view returns (address);
    function wombatRegistry() external view returns (address);
    
    
}
