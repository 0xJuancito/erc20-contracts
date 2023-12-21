// SPDX-License-Identifier: MIT

pragma solidity >0.6.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/ITreasury.sol";

contract _10SHARE is ERC20Burnable, Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    mapping(address => bool) public operators;

    uint public constant DEV_FUND_POOL_ALLOCATION = 5000000000000000000000;
    uint public constant DAO_FUND_POOL_ALLOCATION = 5000000000000000000000;
    uint public constant EQUITY_FUND_POOL_ALLOCATION = 5000000000000000000000;

    ITreasury public treasury;

    uint public constant VESTING_DURATION = 315360000;
    uint public startTime;
    uint public endTime;

    uint public daoFundRewardRate;
    uint public equityFundRewardRate;
    uint public devFundRewardRate;

    address public equityFund;
    address public daoFund;
    address public devFund;

    uint public lastClaimedTime;

    bool public rewardPoolDistributed = false;

    uint public fundMultiplier = 10000;

    modifier onlyPools() {
        require(ITreasury(treasury).hasPool(msg.sender), "!pools");
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Caller is not operator");
        _;
    }

    // Track Share burned
    event ShareBurned(address indexed from, address indexed to, uint amount);

    // Track Share minted
    event ShareMinted(address indexed from, address indexed to, uint amount);

    event DaoClaimRewards(uint paid);
    event DevClaimRewards(uint paid);
    event EquityClaimRewards(uint paid);

    constructor(ITreasury _treasury, uint _startTime, address _daoFund, address _devFund, address _equityFund) public ERC20("10SHARE", "10SHARE") {
        operators[msg.sender] = true;

        _mint(msg.sender, 6 ether);

        startTime = _startTime;
        endTime = startTime + VESTING_DURATION;

        lastClaimedTime = startTime;

        daoFundRewardRate = DAO_FUND_POOL_ALLOCATION.div(VESTING_DURATION);
        devFundRewardRate = DEV_FUND_POOL_ALLOCATION.div(VESTING_DURATION);
        equityFundRewardRate = EQUITY_FUND_POOL_ALLOCATION.div(VESTING_DURATION);

        require(_devFund != address(0), "Address cannot be 0");
        devFund = _devFund;

        require(_daoFund != address(0), "Address cannot be 0");
        daoFund = _daoFund;

        require(_equityFund != address(0), "Address cannot be 0");
        equityFund = _equityFund;

        treasury = _treasury;
    }

    function setDaoFund(address _daoFund) external onlyOperator {
        require(_daoFund != address(0), "zero");
        daoFund = _daoFund;
    }

    function setEquityFund(address _equityFund) external onlyOperator {
        require(_equityFund != address(0), "zero");
        equityFund = _equityFund;
    }

    function setDevFund(address _devFund) external onlyOperator {
        require(_devFund != address(0), "zero");
        devFund = _devFund;
    }

    function unclaimedDaoFund() public view returns (uint _pending) {
        uint _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (lastClaimedTime >= _now) return 0;
        _pending = _now.sub(lastClaimedTime).mul(daoFundRewardRate);
    }

    function unclaimedDevFund() public view returns (uint _pending) {
        uint _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (lastClaimedTime >= _now) return 0;
        _pending = _now.sub(lastClaimedTime).mul(devFundRewardRate);
    }

    function unclaimedEquityFund() public view returns (uint _pending) {
        uint _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (lastClaimedTime >= _now) return 0;
        _pending = _now.sub(lastClaimedTime).mul(equityFundRewardRate);
    }

    /**
     * @dev Claim pending rewards to community and dev fund
     */
    function claimRewards() external {
        uint _pending = unclaimedDaoFund();
        if (_pending > 0 && daoFund != address(0)) {
            emit DaoClaimRewards(_pending.mul(fundMultiplier).div(10000));
            _mint(daoFund, _pending.mul(fundMultiplier).div(10000));
        }
        _pending = unclaimedDevFund();
        if (_pending > 0 && devFund != address(0)) {
            emit DevClaimRewards(_pending.mul(fundMultiplier).div(10000));
            _mint(devFund, _pending.mul(fundMultiplier).div(10000));
        }
        _pending = unclaimedEquityFund();
        if (_pending > 0 && equityFund != address(0)) {
            emit EquityClaimRewards(_pending.mul(fundMultiplier).div(10000));
            _mint(equityFund, _pending.mul(fundMultiplier).div(10000));
        }
        lastClaimedTime = block.timestamp;
    }

    function setOperator(address operator, bool isOperator) public onlyOwner {
        require(operator != address(0), "operator address cannot be 0 address");
        operators[operator] = isOperator;
    }

    function setFundMultiplier(uint _fundMultiplier) external onlyOperator {
        require(_fundMultiplier <= 100 * 10000, "Max fundMultiplier is 100x");
        fundMultiplier = _fundMultiplier;
    }

    /**
     * @notice Operator mints 10SHARE to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of 10SHARE to mint to
     */
    function mint(address recipient_, uint amount_) public onlyOperator {
        _mint(recipient_, amount_);
    }

    function burn(uint amount) public override {
        super.burn(amount);
    }

    // This function is what other Pools will call to mint new SHARE
    function poolMint(address m_address, uint m_amount) external onlyPools {
        _mint(m_address, m_amount);
        emit ShareMinted(address(this), m_address, m_amount);
    }

    // This function is what other pools will call to burn SHARE
    function poolBurnFrom(address b_address, uint b_amount) external onlyPools {
        super.burnFrom(b_address, b_amount);
        emit ShareBurned(b_address, address(this), b_amount);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint _amount,
        address _to
    ) external onlyOperator {
        require(_to != address(0), "cannot send to 0 address!");
        _token.safeTransfer(_to, _amount);
    }

    function amIOperator() public view returns (bool) {
        if (operators[msg.sender])
            return true;
        return false;
    }

    function setTreasuryAddress(ITreasury _treasury) public onlyOperator {
        require(address(_treasury) != address(0), "treasury address can't be 0!");
        treasury = _treasury;
    }
}
