// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@upgradeable/interfaces/IERC20Upgradeable.sol";
import "@upgradeable/access/OwnableUpgradeable.sol";
import "@upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract UniwarRecoverable is OwnableUpgradeable, UUPSUpgradeable {
    event TokensRecovered(address indexed _token, uint256 indexed _amount, address indexed _to);
    event EthRecovered(uint256 indexed _amount, address indexed _to);

    function __UniwarRecoverable_init() internal onlyInitializing {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __UniwarRecoverable_init_unchained();
    }

    function __UniwarRecoverable_init_unchained() internal onlyInitializing {}

    function recoverTokens(address _token, uint256 _amount, address _to) external onlyOwner {
        require(IERC20Upgradeable(_token).transfer(_to, _amount), "UniwarRecoverable: transfer failed");
        emit TokensRecovered(_token, _amount, _to);
    }

    function recoverEth(uint256 _amount, address payable _to) external onlyOwner {
        _to.transfer(_amount);
        emit EthRecovered(_amount, _to);
    }
}
