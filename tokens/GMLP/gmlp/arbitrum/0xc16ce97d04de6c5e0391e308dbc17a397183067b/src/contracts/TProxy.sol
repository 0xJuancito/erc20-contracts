pragma solidity 0.8.17;
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TProxy is TransparentUpgradeableProxy {
    constructor(
        address i,
        address a,
        bytes memory c
    ) TransparentUpgradeableProxy(i, a, c) {}
}
