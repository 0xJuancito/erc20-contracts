// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "../../interfaces/IMasterChef.sol";
import "../../interfaces/IBiswapPair.sol";
import "../../interfaces/IStash.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
/**
    A rewards stasg that stakes the stashed values until they are claimed
    It uses the biswap BUSD-USDT farm to do so 
 */
contract RewardStash is IRewardStash, AccessControl {
    // Reference to the BUSD contract
    ERC20 public busd = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    // Use this to stash busd with this strategy
    function stash(uint256 value) external override {
        busd.transferFrom(address(msg.sender), address(this), value);
    }

    // Use this to unstash busd
    function unstash(uint256 busdValue) external override onlyRole(MANAGER_ROLE) {
        require(busdValue <= busd.balanceOf(address(this)), "Insufficient balance");
        busd.transfer(msg.sender, busdValue);
    }

    function stashValue() external view override returns (uint256) {
       return busd.balanceOf(address(this));
    }

    // Use this function to migrate the capital to another address
    function migrateCapital(address _newStashAddress, uint256 busdAmount) external onlyRole(OWNER_ROLE) {
        require(busdAmount <= busd.balanceOf(address(this)), "Insufficient balance");

        busd.transfer(_newStashAddress, busdAmount);
    }

    // Migrate all the capital to a new address
    function migrateAndDestory(address _newStashAddress) external onlyRole(OWNER_ROLE) {
        busd.transfer(_newStashAddress, busd.balanceOf(address(this))); 

        // Self destruct and transfer any ETH to the owner
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {}
}
