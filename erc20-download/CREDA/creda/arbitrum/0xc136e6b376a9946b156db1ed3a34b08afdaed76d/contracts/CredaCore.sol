// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CredaControl.sol";
contract CredaCore is ERC20Burnable,CredaCtroller{

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    mapping (address => mapping(address => LpStakeInfo)) private _stakingRecords;
    mapping (address => uint256) private _unlockFactor;
    mapping (address => uint256) private _unlockBlockTime;
    mapping(address => uint8) public mineContract;
    mapping (address => uint256) private _unlocks;
    uint256 public _totalUnlocked;




    struct LpStakeInfo {
        uint256 amountStaked;
        uint256 blockTime;
    }

    event LOG_UNLOCK_TRANSFER (
        address indexed from,
        address indexed to,
        uint256 amount
    );

    event LOG_STAKE (
        address indexed staker,
        address indexed token,
        uint256 stakeAmount
    );

    event LOG_UNSTAKE (
        address indexed staker,
        address indexed token,
        uint256 unstakeAmount
    );

    event LOG_CLAIM_UNLOCKED (
        address indexed staker,
        uint256 claimedAmount
    );

    event LOG_SET_UNLOCK_FACTOR (
        address indexed token,
        uint256 factor
    );

    event LOG_SET_UNLOCK_BLOCK_Time (
        address indexed token,
        uint256 blockTime
    );

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_){
        _mint(_msgSender(), 10**26); 
        _mintUnlocked(_msgSender(),  10**26); 
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        _unfreezeTransfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _unfreezeTransfer(sender, recipient, amount);
        uint256 allowance = allowance(sender, msg.sender);
        _approve(sender, msg.sender, allowance.sub(amount, "ERC20: TRANSFER_AMOUNT_EXCEEDED"));
        return true;
    }

   function _unfreezeTransfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _unlocks[sender] = _unlocks[sender].sub(amount, "ERC20: transfer amount exceeds unlocked balance");
        _unlocks[recipient] = _unlocks[recipient].add(amount);
        if(mineContract[sender] == 1){
            _unlocks[recipient] = _unlocks[recipient].sub(amount);
            _totalUnlocked = _totalUnlocked.sub(amount);
        }

        emit LOG_UNLOCK_TRANSFER(sender, recipient, amount);
    }

    function setMineContract(address account, uint8 _lock) public onlyOwner{
        mineContract[account] = _lock;
    }

    function getMineContract(address account) public view onlyOwner returns (uint8)
    {
        return mineContract[account];
    }
   
   function totalUnlocked() external view  returns (uint256) {
        return _totalUnlocked;
    }

    function unlockedOf(address account) public view returns (uint256) {
        return _unlocks[account];
    }

    function lockedOf(address account) public view returns (uint256) {
        return balanceOf(account).sub(_unlocks[account]);
    }

    function _unfreeze(address account, uint256 amount) internal {
        require(balanceOf(account).sub(_unlocks[account]).sub(amount) >= 0);
        _unlocks[account] = _unlocks[account].add(amount);
        _totalUnlocked = _totalUnlocked.add(amount);
    }


   function mintUnlockedToken(address recipient, uint256 amount) onlyAuthorizedMintCaller external {
        _mint(recipient, amount);
        _mintUnlocked(recipient, amount);
        require(totalSupply() <= 10**26, "ERC20: TOTAL_SUPPLY_EXCEEDED");
    }

    function mintLockedToken(address recipient, uint256 amount) onlyAuthorizedMintCaller external {
        _mint(recipient, amount);
        require(totalSupply() <= 10**26, "ERC20: TOTAL_SUPPLY_EXCEEDED");
    }

    function _mintUnlocked(address recipient, uint256 amount) internal {
        _unlocks[recipient] = _unlocks[recipient].add(amount);
        _totalUnlocked = _totalUnlocked.add(amount);
        emit LOG_UNLOCK_TRANSFER(address(0), recipient, amount);
    }

    function burn(uint256 amount) public override  {
        super.burn(amount);
        _unlocks[msg.sender] = _unlocks[msg.sender].sub(amount);
        _totalUnlocked = _totalUnlocked.sub(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
    {
        super.burnFrom(account, amount);
        _unlocks[account] = _unlocks[account].sub(amount);
        _totalUnlocked = _totalUnlocked.sub(amount);
    }


     function getUnlockFactor(address token) external view returns (uint256) {
        return _unlockFactor[token];
    }

    function getUnlockBlockTime(address token) external view returns (uint256) {
        return _unlockBlockTime[token];
    }

    function getStaked(address token) external view returns (uint256) {
        return _stakingRecords[msg.sender][token].amountStaked;
    }

    function getUnlockSpeed(address staker, address token) external view returns (uint256) {
        LpStakeInfo storage info = _stakingRecords[staker][token];
        return _getUnlockSpeed(token, staker, info.amountStaked);
    }

    function claimableUnlocked(address token) external view returns (uint256) {
        LpStakeInfo storage info = _stakingRecords[msg.sender][token];
        return _settleUnlockAmount(msg.sender, token, info.amountStaked, info.blockTime);
    }


    function setUnlockFactor(address token, uint256 _factor) external onlyOwner {
        _unlockFactor[token] = _factor;
        emit LOG_SET_UNLOCK_FACTOR(token, _factor);
    }

    function setUnlockBlockTime(address token, uint256 _blockTime) external onlyOwner {
        _unlockBlockTime[token] = _blockTime;
        emit LOG_SET_UNLOCK_BLOCK_Time(token, _blockTime);
    }

    function stake(address token, uint256 amount) external  returns (bool) {
        require(_unlockFactor[token] > 0, "ERC20: FACTOR_NOT_SET");
        require(_unlockBlockTime[token] > 0, "ERC20: BLOCK_Time_NOT_SET");
        _pullToken(token, msg.sender, amount);
        LpStakeInfo storage info = _stakingRecords[msg.sender][token];
        uint256 unlockedAmount = _settleUnlockAmount(msg.sender, token, info.amountStaked, info.blockTime);
        _updateStakeRecord(msg.sender, token, info.amountStaked.add(amount));
        _unfreeze(msg.sender,unlockedAmount);
        //_mintUnlocked(msg.sender,unlockedAmount);
        emit LOG_STAKE(msg.sender, token, amount);
        return true;
    }

    function unstake(address token, uint256 amount) external  returns (bool) {
        require(amount > 0, "ERC20: ZERO_UNSTAKE_AMOUNT");
        LpStakeInfo storage info = _stakingRecords[msg.sender][token];
        require(amount <= info.amountStaked, "ERC20: UNSTAKE_AMOUNT_EXCEEDED");
        uint256 unlockedAmount = _settleUnlockAmount(msg.sender, token, info.amountStaked, info.blockTime);
        _updateStakeRecord(msg.sender, token, info.amountStaked.sub(amount));
        _unfreeze(msg.sender, unlockedAmount);
        _pushToken(token, msg.sender, amount);
        emit LOG_UNSTAKE(msg.sender, token, amount);
        return true;
    }

    function claimUnlocked(address token) external returns (bool) {
        LpStakeInfo storage info = _stakingRecords[msg.sender][token];
        uint256 unlockedAmount = _settleUnlockAmount(msg.sender, token, info.amountStaked, info.blockTime);
        _updateStakeRecord(msg.sender, token, info.amountStaked);
        _unfreeze(msg.sender, unlockedAmount);
        emit LOG_CLAIM_UNLOCKED(msg.sender, unlockedAmount);
        return true;
    }

    function _updateStakeRecord(address staker, address token, uint256 _amountStaked) internal {
        _stakingRecords[staker][token].amountStaked = _amountStaked;
        _stakingRecords[staker][token].blockTime = block.timestamp;
    }

    function _settleUnlockAmount(address staker, address token, uint256 lpStaked, uint256 upToBlockTime) internal view returns (uint256) {
        uint256 unlockSpeed = _getUnlockSpeed(token, staker, lpStaked);
        uint256 times = block.timestamp.sub(upToBlockTime);
        uint256 unlockedAmount = unlockSpeed.mul(times).div(10**18);
        uint256 lockedAmount = lockedOf(staker);

        if (unlockedAmount > lockedAmount) {
            unlockedAmount = lockedAmount;
        }
        return unlockedAmount;
    }


    function _getUnlockSpeed(address token, address staker, uint256 lpStaked) internal view returns (uint256) {
        uint256 toBeUnlocked = lockedOf(staker);
        uint256 unlockSpeed = _unlockFactor[token].mul(lpStaked);
        uint256 maxUnlockSpeed = toBeUnlocked.mul(10**18).div(_unlockBlockTime[token]);
        if(unlockSpeed > maxUnlockSpeed) {
            unlockSpeed = maxUnlockSpeed;
        }
        return unlockSpeed;
    }


    function _pullToken(address token, address from, uint256 amount) internal {
        IERC20(token).safeTransferFrom(from, address(this), amount);
    }

    function _pushToken(address token, address to, uint256 amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }
}