// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract PetroAccessControl is Initializable, AccessControlUpgradeable, PausableUpgradeable {

    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant REFINERY_ROLE = keccak256("REFINERY_ROLE");
    bytes32 public constant MAP_ROLE = keccak256("MAP_ROLE");
    bytes32 public constant TOKEN_ROLE = keccak256("TOKEN_ROLE");
    bytes32 public constant GAME_MANAGER = keccak256("GAME_MANAGER");
    bytes32 public constant BANK_ROLE = keccak256("BANK_ROLE");
    bytes32 public constant LIQUIDITY_MANAGER_ROLE = keccak256("LIQUIDITY_MANAGER_ROLE");

    address public DevWallet;
    address public RewardManagerAddress;
    address public PetroMapAddress;
    address public OilAddress;
    address public CrudeOilAddress;
    address public RefineryAddress;
    address public PetroConnectAddress;
    address public PetroBankAddress;
    address public PetroLiquidityManagerAddress;

    address public TreasuryAddress;
    address public DevPay;

    address public DAI;
    address public router;


    function __PetroAccessControl_init() initializer public {
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_MANAGER, msg.sender);
        DevWallet = msg.sender;
        // router = address(0x688d21b0B8Dc35971AF58cFF1F7Bf65639937860); // FUJI UNI V2

        DevPay = address(0x573a5841Ba2ab3E98792491083Bb16158E1B7a32); 
        TreasuryAddress = address(0x84594be83f9f150E01d64139d5105d5be27f07B5);

        router = address(0xE592427A0AEce92De3Edee1F18E0157C05861564); // UNI V3 MUMBAI
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setAll(address[] memory _toSet) public onlyRole(GAME_MANAGER) {
        PetroMapAddress = _toSet[0];
        _grantRole(MAP_ROLE, _toSet[0]);

        OilAddress = _toSet[1];
        _grantRole(TOKEN_ROLE, _toSet[1]);

        CrudeOilAddress = _toSet[2];
        _grantRole(TOKEN_ROLE, _toSet[2]);

        RefineryAddress = _toSet[3];
        _grantRole(REWARD_MANAGER_ROLE, _toSet[3]);
        _grantRole(REFINERY_ROLE, _toSet[3]);

        RewardManagerAddress = _toSet[4];
        _grantRole(REWARD_MANAGER_ROLE, _toSet[4]);

        PetroConnectAddress = _toSet[5];
        _grantRole(GAME_MANAGER, _toSet[5]);

        PetroBankAddress = _toSet[6];
        _grantRole(BANK_ROLE, _toSet[6]);

        PetroLiquidityManagerAddress = _toSet[7];
        _grantRole(LIQUIDITY_MANAGER_ROLE, _toSet[7]);

        DAI = _toSet[8];
    }
}