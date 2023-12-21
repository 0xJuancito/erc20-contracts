// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract HedgeCoinStaking is OwnableUpgradeable {
    uint8 public stakeTax ;
    uint8 public unStakeTax;
    address public feeAddress;

    uint256 public rewardRate;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public _balances;

    ERC20PresetMinterPauser public rewardsToken;
    ERC20PresetMinterPauser public stakingToken;

    function init(address _stakingToken, address _rewardsToken) initializer public  {
        __Ownable_init();
        stakingToken = ERC20PresetMinterPauser(_stakingToken);
        rewardsToken = ERC20PresetMinterPauser(_rewardsToken);
        feeAddress = msg.sender;
        stakeTax = 2;
        unStakeTax = 2;
        rewardRate = 100;
    }

    function rewardPerToken() public view returns (uint256) {
        uint256 _totalSupply = stakingToken.balanceOf(address(this));

        if (_totalSupply == 0) {
            return 0;
        }
        return rewardPerTokenStored + (((block.number - lastUpdateBlock) * rewardRate * 1e18) / _totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        if(_balances[account] == 0) {
            return  rewards[account];
        }
        return ((_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }

    function stakedAmount(address account) external view returns (uint256) {
        return _balances[account];
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;

        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    function stake(uint256 _amount) external updateReward(msg.sender) {
        uint256 fee = 0;
        if(stakeTax > 0){
            fee = (_amount * stakeTax) / 100;
            stakingToken.transferFrom(msg.sender, feeAddress, fee);
        }
        _balances[msg.sender] += _amount - fee;
        stakingToken.transferFrom(msg.sender, address(this), _amount - fee);
    }

    function totalSupply() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function withdraw(uint256 _amount) external updateReward(msg.sender) {
        require(_balances[msg.sender] >= _amount, "Insuficient balance");
        _balances[msg.sender] -= _amount;
        uint256 fee = 0;
        if(unStakeTax > 0){
            fee = (_amount * stakeTax) / 100;
            stakingToken.transfer(feeAddress, fee);
        }

        stakingToken.transfer(msg.sender, _amount - fee);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        rewardsToken.mint(msg.sender, reward);
    }

    function setRewardRate(uint256 rate) external onlyOwner {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        rewardRate = rate;
    }

    function setFeeAddress(address newAddress) external onlyOwner {
        require(address(feeAddress) != newAddress, "New address is the same as old address");
        require(newAddress != address(0), "New address cannot be 0x00");
        feeAddress = newAddress;
    }

    function setStakeTax(uint8 tax) external onlyOwner {
        require(tax <= 100, "Tax cannot be greater than 100%");
        stakeTax = tax;
    }

    function setUnStakeTax(uint8 tax) external onlyOwner {
        require(tax <= 100, "Tax cannot be greater than 100%");
        unStakeTax = tax;
    }

    function destroy() external onlyOwner {
        require(stakingToken.balanceOf(address(this)) == 0, "Tokens still in pool");
        selfdestruct(payable(msg.sender));
    }
}
