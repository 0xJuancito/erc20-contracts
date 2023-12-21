// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

abstract contract Mintable is Ownable {
    event SetDailyLimitSetter(address indexed newSetter);
    event SetMinterTimelock(address indexed setter, uint256 oldDuration, uint256 newDuration);
    event AllowMinter(address indexed setter, address indexed target, bool allowed);
    event SetDailyMintLimit(address indexed setter, uint256 oldLimit, uint256 newLimit);

    struct MinterData {
        bool allowed;
        uint256 dailyLimit;
    }

    uint256 public constant DAILY_INTERVAL = 1 days;

    address[] public minters;
    mapping(address => MinterData) public allowMinting;
    mapping(address => mapping(uint256 => uint256)) public dailyMint;
    address public dailyLimitSetter;

    constructor() {
        dailyLimitSetter = msg.sender;
    }

    function setDailyLimitSetter(address setter) public onlyOwner {
        dailyLimitSetter = setter;
        emit SetDailyLimitSetter(setter);
    }

    function setAllowMinting(address _address, bool _allowed) public onlyOwner {
        allowMinting[_address].allowed = _allowed;
        if (_allowed) {
            minters.push(_address);
        }
        emit AllowMinter(_msgSender(), _address, _allowed);
    }

    // Just for prevent flash loan or other attacks. Mint limit shold be set in target contracts.
    function setDailyMintLimit(address _address, uint256 _limit) public {
        require(msg.sender == dailyLimitSetter, "ND");
        emit SetDailyMintLimit(_msgSender(), allowMinting[_address].dailyLimit, _limit);
        allowMinting[_address].dailyLimit = _limit;
    }

    modifier onlyMinter {
        require(allowMinting[_msgSender()].allowed, "NM");
        _;
    }

    function mintDailyLimited(address _address, uint256 _amount) public view returns (bool) {
        if (allowMinting[_address].dailyLimit == 0) {
            return false;
        }

        return dailyMint[_address][block.timestamp / DAILY_INTERVAL] + _amount > allowMinting[_address].dailyLimit;
    }

    function increaseMint(uint256 _amount) internal {
        require(!mintDailyLimited(_msgSender(), _amount), "limit");

        dailyMint[_msgSender()][block.timestamp / DAILY_INTERVAL] += _amount;
    }
}

contract CopycatToken is ERC20, ERC20Burnable, Ownable, Mintable {
    uint256 public totalBurn = 0;

    constructor() ERC20('Copycat Token', 'COPYCAT') {
        
    }

    function mint(address _to, uint256 _amount) public onlyMinter {
        increaseMint(_amount);
        _mint(_to, _amount);
    }

    function burn(uint256 amount) public override {
        ERC20Burnable.burn(amount);
        totalBurn += amount;
    }

    function burnFrom(address account, uint256 amount) public override {
        ERC20Burnable.burnFrom(account, amount);
        totalBurn += amount;
    }
}