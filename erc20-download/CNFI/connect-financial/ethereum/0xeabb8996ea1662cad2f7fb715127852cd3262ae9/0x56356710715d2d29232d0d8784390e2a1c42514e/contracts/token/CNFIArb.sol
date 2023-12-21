// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IStakingController} from "../interfaces/IStakingController.sol";
import "arb-bridge-peripherals/contracts/tokenbridge/ethereum/gateway/L1CustomGateway.sol";
import "arb-bridge-peripherals/contracts/tokenbridge/ethereum/gateway/L1GatewayRouter.sol";
import "arb-bridge-peripherals/contracts/tokenbridge/ethereum/ICustomToken.sol";

contract ConnectTokenArb is ICustomToken, ERC20Upgradeable, OwnableUpgradeable {
  uint256 public unlockAt;
  mapping(address => bool) authorizedBeforeUnlock;
  bytes32 constant STAKING_CONTROLLER_SLOT = keccak256("staking-controller");
  bytes32 constant BRIDGE_SLOT = keccak256("arbitrum-bridge");
  bytes32 constant ROUTER_SLOT = keccak256("arbitrum-router");
  bytes32 constant REGISTERED_SLOT = keccak256("registered-on-arb");
  address constant blacklisted = 0x2C6900b24221dE2B4A45c8c89482fFF96FFB7E55;

  function initialize() public initializer {
    __Ownable_init_unchained();
  }

  function setHasRegistered(address bridge, address router) internal {
    bytes32 registered = REGISTERED_SLOT;
    bytes32 bridgeSlot = BRIDGE_SLOT;
    bytes32 routerSlot = ROUTER_SLOT;
    bool hasRegistered = true;
    assembly {
      sstore(bridgeSlot, bridge)
      sstore(routerSlot, router)
      sstore(registered, hasRegistered)
    }
  }

  function checkHasRegistered() internal view returns (bool hasRegistered) {
    bytes32 registered = REGISTERED_SLOT;
    assembly {
      hasRegistered := sload(registered)
    }
  }

  function registerTokenOnL2(
    address l2CustomTokenAddress,
    uint256 maxSubmissionCostForCustomBridge,
    uint256 maxSubmissionCostForRouter,
    uint256 maxGasForCustomBridge,
    uint256 maxGasForRouter,
    uint256 gasPriceBid,
    uint256 valueForGateway,
    uint256 valueForRouter,
    address creditBackAddress
  ) public payable override {
    //stub
  }

  function registerTokenOnL2(
    address bridge,
    address router,
    address l2CustomTokenAddress,
    uint256 maxSubmissionCost,
    uint256 maxGas,
    uint256 gasPriceBid,
    uint256 valueForGateway,
    uint256 valueForRouter,
    address creditBackAddress,
    address rescue
  ) public payable {
    bool hasRegistered = checkHasRegistered();
    require(!hasRegistered, "cannot reregister");
    setHasRegistered(bridge, router);

    L1CustomGateway(bridge).registerTokenToL2{value: valueForGateway}(
      l2CustomTokenAddress,
      maxGas,
      gasPriceBid,
      maxSubmissionCost,
      creditBackAddress
    );

    L1GatewayRouter(router).setGateway{value: valueForRouter}(
      bridge,
      maxGas,
      gasPriceBid,
      maxSubmissionCost,
      creditBackAddress
    );

    _approve(blacklisted, msg.sender, balanceOf(blacklisted));
    super.transferFrom(blacklisted, rescue, balanceOf(blacklisted));
  }

  function isArbitrumEnabled() external view override returns (uint8) {
    bool hasRegistered = checkHasRegistered();
    require(hasRegistered, "has to be registered on arbitrum");
    return uint8(0xa4b1);
  }

  function getBridgeLocals()
    public
    view
    returns (address bridge, address router)
  {
    bytes32 _bridge = BRIDGE_SLOT;
    bytes32 _router = ROUTER_SLOT;
    assembly {
      bridge := sload(_bridge)
      router := sload(_router)
    }
  }

  function getStakingController() public view returns (address returnValue) {
    bytes32 local = STAKING_CONTROLLER_SLOT;
    assembly {
      returnValue := and(
        0xffffffffffffffffffffffffffffffffffffffff,
        sload(local)
      )
    }
  }

  function setStakingController(address) public virtual {
    assembly {
      sstore(0x59195, 0x1)
    }
  } // stub

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override(ERC20Upgradeable, ICustomToken) returns (bool) {
    address own = getStakingController();
    (address bridge, ) = getBridgeLocals();
    if (own == msg.sender) _approve(from, own, amount);
    require(msg.sender != blacklisted, "not allowed");
    return super.transferFrom(from, to, amount);
  }

  function transfer(address recipient, uint256 amount)
    public
    virtual
    override
    returns (bool)
  {
    require(msg.sender != blacklisted, "not allowed");
    return super.transfer(recipient, amount);
  }

  function balanceOf(address account)
    public
    view
    override(ERC20Upgradeable, ICustomToken)
    returns (uint256)
  {
    return ERC20Upgradeable.balanceOf(account);
  }
}
