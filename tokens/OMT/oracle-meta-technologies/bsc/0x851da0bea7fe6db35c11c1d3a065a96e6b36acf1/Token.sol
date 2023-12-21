// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";


contract Token is ERC20, Ownable {
    using SafeMath for uint256;

    uint256 private constant _percent = 21;
    uint256 private constant _stakingPeriodInDays = 365;
    uint256 private constant _withdrawalPeriod = 2 weeks;

    constructor()  ERC20('Oracle Meta Technologies', 'OMT') {
        _setupDecimals(4);
        _mint(msg.sender, 1_100_000_000 * 1e4);
    }

    struct Stake {
        uint256 id;
        uint256 startAt;
        uint256 reward;
        uint256 profitCount;
        uint256 amount;
    }

    address[] private _stakeholders;

    mapping(address => Stake[]) private _stakes;

    function createStake(uint256 _amount) external returns (bool)
    {
        require(_amount > 0, "Amount must be greater than 0");

        _burn(msg.sender, _amount);
        _addStakeholder(msg.sender);
        uint256 stakeNumber = _stakes[msg.sender].length + 1;

        _stakes[msg.sender].push(
            Stake({
                id: stakeNumber,
                amount: _amount,
                reward : 0,
                profitCount: 0,
                startAt: block.timestamp
            })
        );

        return true;
    }

    function isStakeholder(address _address) public view returns (bool, uint256)
    {
        for (uint256 s = 0; s < _stakeholders.length; s += 1){
            if (_address == _stakeholders[s]) return (true, s);
        }
        return (false, 0);
    }

    function getStake(address _stakeholder, uint256 _id) public view returns (uint256, uint256, uint256, uint256, uint256)
    {
        for (uint256 s = 0; s < _stakes[_stakeholder].length; s += 1) {
            if (_stakes[_stakeholder][s].id == _id) {
                return (
                    _stakes[_stakeholder][s].id,
                    _stakes[_stakeholder][s].startAt,
                    _stakes[_stakeholder][s].reward,
                    _stakes[_stakeholder][s].profitCount,
                    _stakes[_stakeholder][s].amount
                );
            }
        }

        return (0,0,0,0,0);
    }

    function totalStakes() public view returns (uint256)
    {
        uint256 _totalStakes = 0;
        for (uint256 s = 0; s < _stakeholders.length; s += 1){
            _totalStakes += _stakes[_stakeholders[s]].length;
        }
        return _totalStakes;
    }

    function stakesCount(address _address) public view virtual returns (uint)
    {
        return _stakes[_address].length;
    }

    function getStakesIds(address _stakeholder) external view returns (uint[] memory)
    {
        uint[] memory ids = new uint[](_stakes[_stakeholder].length);

        for (uint256 s = 0; s < _stakes[_stakeholder].length; s += 1) {
            ids[s] = _stakes[_stakeholder][s].id;
        }

        return ids;
    }

    ////

    function calculateDailyReward(address _stakeholder, uint256 _stakeId) public view returns(uint256)  {
        (,,,,uint256 amount) = getStake(_stakeholder, _stakeId);
        return _stakeDailyProfit(amount);
    }

    function getAvailableProfitCount(address _stakeholder, uint256 _stakeId) public view returns (uint256)
    {
        (,uint256 startAt,,uint256 profitCount,) = getStake(_stakeholder, _stakeId);

        return _stakeAvailableProfits(startAt, profitCount);
    }

    function getAward(uint256 _stakeId) public view returns (uint256)
    {
        (,uint256 startAt,,uint256 profitCount, uint256 amount) = getStake(msg.sender, _stakeId);

        return _stakeAward(amount, startAt, profitCount);
    }

    function makeAward(uint256 _stakeId) public payable returns (bool) {
        (,uint256 startAt,,uint256 profitCount, uint256 amount) = getStake(msg.sender, _stakeId);


        uint256 award = _stakeAward(amount, startAt, profitCount);
        uint256 availableProfitCount = _stakeAvailableProfits(startAt, profitCount);

        if (award <= 0) {
            return false;
        }

        if (availableProfitCount <= 0) {
            return false;
        }

        award = _takeOfCommissionFromAward(award);

        for (uint256 s = 0; s < _stakes[msg.sender].length; s += 1) {
            if (_stakes[msg.sender][s].id == _stakeId) {
                _stakes[msg.sender][s].profitCount = _stakes[msg.sender][s].profitCount.add(availableProfitCount);
                _stakes[msg.sender][s].reward = _stakes[msg.sender][s].reward.add(award);
            }
        }

        _mint(msg.sender, award);

        return true;
    }

    function isStakeMayBeClosed(uint256 _stakeId) public view returns (bool)
    {
        (,uint256 startAt,,,) = getStake(msg.sender, _stakeId);

        return _isStakeMayClosed(startAt);
    }

    function closeStaking(uint256 _stakeId) public payable returns (bool)
    {
        (,uint256 startAt,,uint256 profitCount, uint256 amount) = getStake(msg.sender, _stakeId);


        if (_isStakeMayClosed(startAt) == false) {
            return false;
        }

        uint256 award = _stakeAward(amount, startAt, profitCount);

        award = _takeOfCommissionFromAward(award);

        uint256 availableProfitCount = _stakeAvailableProfits(startAt, profitCount);

        for (uint256 s = 0; s < _stakes[msg.sender].length; s += 1) {
            if (_stakes[msg.sender][s].id == _stakeId) {
                delete _stakes[msg.sender][s];
            }
        }
        if (_stakes[msg.sender].length == 0) {
            (,uint256 index) = isStakeholder(msg.sender);
            delete _stakeholders[index];
        }

        amount = amount.add(award);
        if (amount > 0) {
            _mint(msg.sender, amount);
        }
        return true;
    }

    function _addStakeholder(address _stakeholder) private
    {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) _stakeholders.push(_stakeholder);
    }

    function  _stakeDailyProfit(uint256 _amount) private view returns (uint256) {

        return _amount.div(100).mul(_percent).div(_stakingPeriodInDays);
    }

    function _stakeAvailableProfits(uint256 startAt, uint256 profitCount) private view returns (uint256) {
        uint256 diff = block.timestamp.sub(startAt);
        uint256 availableProfits = diff.div(_withdrawalPeriod).sub(profitCount);
        uint256 maxAvailableProfitCount = 26 - profitCount;
        if (availableProfits > maxAvailableProfitCount) {
            return maxAvailableProfitCount;
        }
        return availableProfits;
    }

    function _stakeAward(uint256 amount, uint256 startAt, uint256 profitCount) private view returns (uint256)
    {
        uint256 availableProfits = _stakeAvailableProfits(startAt, profitCount);
        uint256 profitByDay = _stakeDailyProfit(amount);
        if (profitByDay <= 0) {
            return 0;
        }

        return profitByDay.mul(14).mul(availableProfits);
    }

    function _isStakeMayClosed(uint256 startAt) private view returns (bool)
    {
        return (block.timestamp - startAt) / 365 days >= 1;
    }

    function _takeOfCommissionFromAward(uint256 amount) private returns (uint256)
    {
        uint256 commission = amount.div(1000).mul(23);
        _mint(owner(), commission.div(2));
        return amount.sub(commission);
    }

}
