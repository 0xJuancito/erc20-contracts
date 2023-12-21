// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

abstract contract GalixContextUpgradeable is ContextUpgradeable {

    function isCogiChain() internal view returns (bool){
        return block.chainid == 5555;
    }

    function isNotCogiChain() internal view returns (bool){
        return !isCogiChain();
    }

    function isViaWalletProxy() internal view returns (bool){
        return (isCogiChain() && msg.sender == address(0xe9e0e209254DA4B900A02425519a2530ce31919b));
    }

    function _msgSenderViaWalletProxy() internal view virtual returns (address) {
        if (isViaWalletProxy()) {
            return tx.origin;
        }
        return msg.sender;
    }

    modifier onlyWalletProxyOrNotCogiChain() {
        require(isViaWalletProxy() || isNotCogiChain(), "_msgSender not allowed");
        _;
    }
}
