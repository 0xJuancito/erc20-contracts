//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "../access/GameAdmin.sol";
import "./ERC20Stake.sol";

abstract contract ERC20BaseToken is ERC20PausableUpgradeable, ERC20Stake {

    event CommunityFuncAccountChanged(address oldAccount, address newAccount);
    event TokenProduced(address account, uint256 amount, uint64 txId, string reason);
    event TokenDestroyed(address account, uint256 amount, uint64 txId, string reason);
    event RevenueClaimed(address account, uint256 amount, uint64 txId);

    error InvalidFundAccount();

    address public communityFundAccount;

    function __ERC20BaseToken_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
        __ERC20Pausable_init();
        __SuperAdmin_init_unchained();
        __GameAdmin_init_unchained();
    }

    function changeCommunityFundAccount(address newAccount) public onlySuperAdmin {
        emit CommunityFuncAccountChanged(communityFundAccount, newAccount);
        communityFundAccount = newAccount;
    }

    function produce(address toAccount, uint256 amount, uint64 txId, string memory reason) public virtual onlyGameAdmin idempotent(txId) {
        _mint(toAccount, amount);
        emit TokenProduced(toAccount, amount, txId, reason);
    }

    function destroy(uint256 amount, uint64 txId, string memory reason) public virtual onlyGameAdmin idempotent(txId) {
        _burn(address(this), amount);
        emit TokenDestroyed(gameAdmin, amount, txId, reason);
    }

    function claimRevenue(uint256 amount, uint64 timestamp, uint64 txId) public virtual onlyGameAdmin idempotent(txId) {
        if (amount <= 0) revert IllegalAmount();
        if (communityFundAccount == address(0)) revert InvalidFundAccount();

        _mint(communityFundAccount, amount);
        _setClaimTs(address(this), timestamp);
        emit RevenueClaimed(communityFundAccount, amount, txId);
    }

    function _transferFromContract(address toAccount, uint256 amount) internal virtual override {
        // implement _transferFromContract by mint
        _mint(toAccount, amount);
    }

    function _transferToContract(address fromAccount, uint256 amount) internal virtual override returns (bool) {
        // implement _transferToContract by burn
        if (communityFundAccount == address(0)) {
            _burn(fromAccount, amount);
            return false;
        } else {
            _transfer(fromAccount, communityFundAccount, amount);
            return true;
        }
    }
}