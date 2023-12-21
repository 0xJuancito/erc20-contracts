// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../interfaces/IMultiAssetTreasury.sol";
import "./../Operator.sol";

contract SSX is ERC20Burnable, Operator {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // TOTAL SUPPLY = 10.000.000 SSX
    uint256 public constant MAX_SUPPLY = 10000000 ether;
    uint256 public constant DEV_FUND_ALLOCATION = 1000000 ether; // 1.000.000 SSX, initial mint and deposit to llamapay for distribution
    uint256 public constant DAO_FUND_ALLOCATION = 1000000 ether; // 1.000.000 SSX
    uint256 public constant LAUNCH_PAD_ALLOCATION = 45000 ether; // 45.000 SSX at 0.5$ initial price

    IMultiAssetTreasury public treasury;
    address public masterChef;

    address[] public excludeTotalSupply;

    uint256 public constant VESTING_DURATION = 1095 days; // 3 years
    uint256 public startTime;
    uint256 public endTime;

    uint256 public daoFundRewardRate;

    address public daoFund;
    address public devFund;

    uint256 public lastClaimedTime;

    bool public rewardPoolDistributed = false;
    bool public genesisDistributed = false;

    modifier onlyPoolsOrMasterChef() {
        require(IMultiAssetTreasury(treasury).hasPool(msg.sender) || msg.sender == masterChef, "!pools || !masterChef");
        _;
    }

    // Track Share burned
    event ShareBurned(address indexed from, address indexed to, uint256 amount);
    // Track Share minted
    event ShareMinted(address indexed from, address indexed to, uint256 amount);
    event DaoClaimRewards(uint256 paid);
    event GenesisDistributed(uint256 amount);
    event FarmRewardDistribute(address indexed farmContract, address indexed poolReserve);

    constructor(IMultiAssetTreasury _treasury, uint256 _startTime, address _devFund, address _daoFund) public ERC20("SSX", "SSX") {

        startTime = _startTime;
        endTime = startTime + VESTING_DURATION;

        lastClaimedTime = startTime;

        daoFundRewardRate = DAO_FUND_ALLOCATION.div(VESTING_DURATION);

        require(_devFund != address(0), "Address cannot be 0");
        devFund = _devFund;
        _mint(_devFund, DEV_FUND_ALLOCATION);
        _mint(_devFund, LAUNCH_PAD_ALLOCATION);

        require(_daoFund != address(0), "Address cannot be 0");
        daoFund = _daoFund;

        treasury = _treasury;
    }

    function circulatingSupply() public view returns (uint256) {
        uint256 cirSupply = totalSupply();
        for (uint256 i = 0; i < excludeTotalSupply.length; i++) {
            cirSupply = cirSupply.sub(balanceOf(excludeTotalSupply[i]));
        }
        return cirSupply;
    }

    // After Launchpad, @dev will decide the amount for genesis (compensation)
    function distributeGenesis(uint256 _amount, address _genesis) public onlyOperator {
        require(!genesisDistributed, "Already distributed");
        genesisDistributed = true;
        _mint(_genesis, _amount);
        emit GenesisDistributed(_amount);
    }

    function unclaimedDaoFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (lastClaimedTime >= _now) return 0;
        _pending = _now.sub(lastClaimedTime).mul(daoFundRewardRate);
    }

    /**
     * @dev Claim pending rewards to community and dev fund
     */

    function claimRewards() external {
        uint256 _pending = unclaimedDaoFund();
        if (_pending > 0 && daoFund != address(0)) {
            emit DaoClaimRewards(_pending);
            _mint(daoFund, _pending);
        }
        lastClaimedTime = block.timestamp;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    // This function is what other Pools will call to mint new SHARE
    function poolMint(address m_address, uint256 m_amount) external onlyPoolsOrMasterChef {
        uint256 _circulatingSupply = totalSupply();
        require(m_amount.add(_circulatingSupply) <= MAX_SUPPLY, "Exceed total supply");

        _mint(m_address, m_amount);
        emit ShareMinted(address(this), m_address, m_amount);
    }

    // This function is what other pools will call to burn SHARE
    function poolBurnFrom(address b_address, uint256 b_amount) external onlyPoolsOrMasterChef {
        super.burnFrom(b_address, b_amount);
        emit ShareBurned(b_address, address(this), b_amount);
    }

    function addExcludeTotalSupply(address _rewardPool) public onlyOperator {
        require(_rewardPool != address(0), "Invalid address");
        excludeTotalSupply.push(_rewardPool);
    }

    function setDaoFund(address _daoFund) external onlyOperator {
        require(_daoFund != address(0), "zero");
        daoFund = _daoFund;
    }

    function setDevFund(address _devFund) external onlyOperator {
        require(_devFund != address(0), "zero");
        devFund = _devFund;
    }

    function setMasterChef(address _masterChef) external onlyOperator {
        require(_masterChef != address(0), "Invalid address" );
        masterChef = _masterChef;
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        require(_to != address(0), "cannot send to 0 address!");
        _token.safeTransfer(_to, _amount);
    }

    function setTreasuryAddress(IMultiAssetTreasury _treasury) public onlyOperator {
        require(address(_treasury) != address(0), "treasury address can't be 0!");
        treasury = _treasury;
    }
}
