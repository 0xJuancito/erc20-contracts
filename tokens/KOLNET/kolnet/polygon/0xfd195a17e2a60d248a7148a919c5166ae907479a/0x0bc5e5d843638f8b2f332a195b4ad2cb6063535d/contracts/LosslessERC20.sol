// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./ILosslessController.sol";

/**
 * @notice Implements Lossless protocol
 & @dev Based on https://github.com/Lossless-Cash/lossless-v2/blob/master/contracts/LERC20.sol
 */
contract LosslessERC20 is ERC20Upgradeable {

    event LosslessAdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event RecoveryAdminChangeProposed(address indexed candidate);
    event RecoveryAdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event LosslessTurnOffProposed(uint256 turnOffDate);
    event LosslessTurnedOff();
    event LosslessTurnedOn();
    
    
    address public admin;
    address public recoveryAdmin;
    address private recoveryAdminCanditate;
    bytes32 private recoveryAdminKeyHash;
    uint256 public timelockPeriod;
    uint256 public losslessTurnOffTimestamp;
    bool public isLosslessTurnOffProposed;
    bool public isLosslessOn;
    ILosslessController public lossless;

    /**
     * @notice Initialize Lossless data
     * @param _admin Project owner’s administrative wallet address, this will be used in Lossless governance decision. Token creators should set a wallet that they are planning on using to interact with Lossless protocol.
     * @param _recoveryAdmin Project owner’s wallet that is used to change admin. Token creators should use multisig for this and keep it as secure as possible as this wallet allows changing the admin wallet.
     * @param _timelockPeriod Timelock period in seconds dedicated for turning Lossless turn off. In case project decides to turn off Lossless they would have to wait for this period after initially proposing to turn the Lossless functionality off. Recommended timelockPeriod is 24 hours or 86400 seconds. Any lower timelockPeriod will be considered unsafe and will be marked as such in Lossless platform.
     * @param _lossless Lossless protocol controller address. Should be set to Lossless Controller address. Lossless Controller address is different on different chains. Any other address will not allow the token to function properly. You can find appropriate controller address here: https://lossless-cash.gitbook.io/lossless/technical-reference/lossless-controller/deployments
     */
    function __LosslessERC20_init_unchained(address _admin, address _recoveryAdmin, uint256 _timelockPeriod, ILosslessController _lossless) internal onlyInitializing {
        admin = _admin;
        recoveryAdmin = _recoveryAdmin;
        timelockPeriod = _timelockPeriod;
        lossless = _lossless;
        if(address(lossless) != address(0)){
            isLosslessOn = true;
        }
    }

    // --- LOSSLESS modifiers ---

    modifier lssAprove(address spender, uint256 amount) {
        if (isLosslessOn) {
            lossless.beforeApprove(_msgSender(), spender, amount);
        } 
        _;
    }

    modifier lssTransfer(address recipient, uint256 amount) {
        if (isLosslessOn) {
            lossless.beforeTransfer(_msgSender(), recipient, amount);
        } 
        _;
    }

    modifier lssTransferFrom(address sender, address recipient, uint256 amount) {
        if (isLosslessOn) {
            lossless.beforeTransferFrom(_msgSender(), sender, recipient, amount);
        }
        _;
    }

    modifier lssIncreaseAllowance(address spender, uint256 addedValue) {
        if (isLosslessOn) {
            lossless.beforeIncreaseAllowance(_msgSender(), spender, addedValue);
        }
        _;
    }

    modifier lssDecreaseAllowance(address spender, uint256 subtractedValue) {
        if (isLosslessOn) {
            lossless.beforeDecreaseAllowance(_msgSender(), spender, subtractedValue);
        }
        _;
    }

    modifier onlyRecoveryAdmin() {
        require(_msgSender() == recoveryAdmin, "LosslessERC20: Must be recovery admin");
        _;
    }


    // --- LOSSLESS management ---

    function getAdmin() external view returns (address) {
        return admin;
    }

    function transferOutBlacklistedFunds(address[] calldata from) external {
        require(_msgSender() == address(lossless), "LERC20: Only lossless contract");
        for (uint i = 0; i < from.length; i++) {
            _transfer(from[i], address(lossless), balanceOf(from[i]));
        }
    }

    function setLosslessAdmin(address newAdmin) external onlyRecoveryAdmin {
        require(newAdmin != address(0), "LERC20: Cannot be zero address");
        emit LosslessAdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function transferRecoveryAdminOwnership(address candidate, bytes32 keyHash) external onlyRecoveryAdmin {
        require(candidate != address(0), "LERC20: Cannot be zero address");
        recoveryAdminCanditate = candidate;
        recoveryAdminKeyHash = keyHash;
        emit RecoveryAdminChangeProposed(candidate);
    }

    function acceptRecoveryAdminOwnership(bytes memory key) external {
        require(_msgSender() == recoveryAdminCanditate, "LERC20: Must be canditate");
        require(keccak256(key) == recoveryAdminKeyHash, "LERC20: Invalid key");
        emit RecoveryAdminChanged(recoveryAdmin, recoveryAdminCanditate);
        recoveryAdmin = recoveryAdminCanditate;
        recoveryAdminCanditate = address(0);
        recoveryAdminKeyHash = bytes32(0);
    }

    function proposeLosslessTurnOff() external onlyRecoveryAdmin {
        losslessTurnOffTimestamp = block.timestamp + timelockPeriod;
        isLosslessTurnOffProposed = true;
        emit LosslessTurnOffProposed(losslessTurnOffTimestamp);
    }

    function executeLosslessTurnOff() external onlyRecoveryAdmin {
        require(isLosslessTurnOffProposed, "LERC20: TurnOff not proposed");
        require(losslessTurnOffTimestamp <= block.timestamp, "LERC20: Time lock in progress");
        isLosslessOn = false;
        isLosslessTurnOffProposed = false;
        emit LosslessTurnedOff();
    }

    function executeLosslessTurnOn() external onlyRecoveryAdmin {
        isLosslessTurnOffProposed = false;
        isLosslessOn = true;
        emit LosslessTurnedOn();
    }

    // --- ERC20 overriden methods ---

    function approve(address spender, uint256 amount) public virtual override lssAprove(spender, amount) returns (bool) {
        return super.approve(spender, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override lssIncreaseAllowance(spender, addedValue) returns (bool) {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override lssDecreaseAllowance(spender, subtractedValue) returns (bool) {
        return super.decreaseAllowance(spender, subtractedValue);
    }

    function transfer(address to, uint256 amount) public virtual override lssTransfer(to, amount) returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override lssTransferFrom(from, to, amount) returns (bool) {
        return super.transferFrom(from, to, amount);
    }


    uint256[50] private __gap;
}