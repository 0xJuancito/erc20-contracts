// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "@openzeppelin/contracts/access/Ownable.sol";

contract AntiSnipe is Ownable {

    bool canTrade = false;
    bool sellEnabled = false;
    address poolContract;
    uint256 maxAllowedBuyAmount = type(uint256).max;
    uint256 antiSnipeBlockInterval;
    uint256 antiSnipeStartBlock;

    uint256 maxAllowedBalance = type(uint256).max; //no restriction be default

    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isBlacklisted;


    error TRADING_NOT_ENABLED();
    error MAX_BUY_AMOUNT();
    error MAX_ALLOWED_BALANCE();
    error BLACKLISTED();
    error SELL_NOT_ENABLED();

    function _beforeTokenTransfer(
        address from, address to, uint256 amount, uint256 balanceTo
    ) internal view {

        if(isBlacklisted[from] || isBlacklisted[to]) {
            revert BLACKLISTED();
        }

        if (!canTrade && !isWhitelisted[from] && from != address(0)) {
            revert TRADING_NOT_ENABLED();
        }

        if(poolContract != address(0) && to == poolContract) {
           if(!sellEnabled) {
            revert SELL_NOT_ENABLED();
           }
        }

        if(poolContract != address(0) && from == poolContract) {

            if(!isWhitelisted[to] && block.number < antiSnipeStartBlock + antiSnipeBlockInterval) { 
                // Max Holding amount
                //IMPORTANT from == poolContract condition is required here.
                if( balanceTo + amount > maxAllowedBalance) { 
                    revert MAX_ALLOWED_BALANCE();
                }

                if(amount > maxAllowedBuyAmount) {
                    revert MAX_BUY_AMOUNT();
                }
            }

        }
    }

    function blacklist(address[] calldata _targets) external onlyOwner {
        for(uint256 i=0; i< _targets.length; i++) {
            isBlacklisted[_targets[i]] = true;

            if(isWhitelisted[_targets[i]]) {
                isWhitelisted[_targets[i]] = false;
            }
        }
    }

    function removeBlacklist(address[] calldata _targets) external onlyOwner {
        for(uint256 i=0; i< _targets.length; i++) {
            isBlacklisted[_targets[i]] = false;
        }
    }
    

    function updateWhitelists(address[] calldata _targets, bool[] calldata value) external onlyOwner {
        for(uint256 i=0; i< _targets.length; i++) {
            _updateWhitelist(_targets[i], value[i]);
        }
    }

    function updateWhitelist(address target, bool value) external onlyOwner {
        _updateWhitelist(target, value);
    }

    function enableTrading() external onlyOwner {
        require(!canTrade, "ALREADY ENABLED");
        canTrade = true;
    }


    function setAntiSnipeData(
        address _poolContract, 
        uint256 _maxAllowedBuyAmount, 
        uint256 _antiSnipeBlockInterval, 
        uint256 _maxAllowedBalance,
        bool _sellEnabled
    ) external onlyOwner {
        poolContract = _poolContract;
        maxAllowedBuyAmount = _maxAllowedBuyAmount;
        antiSnipeBlockInterval = _antiSnipeBlockInterval;
        maxAllowedBalance = _maxAllowedBalance;
        antiSnipeStartBlock = block.number;
        sellEnabled = _sellEnabled;
    }

    function _updateWhitelist(address _target, bool value) internal {
        isWhitelisted[_target] = value;

        //remove from blacklist if whitelisted
        if(value) isBlacklisted[_target] = false;
    }

}
