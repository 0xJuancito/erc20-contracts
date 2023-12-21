// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
import "./Token.sol";

contract GalacticArenaToken is Token {
    using SafeMath for uint256;
    uint256 public maxSupply = 10**9 * 10**18;
    mapping (address => bool) private _isExcludedFromFees;
    mapping(address => bool) bots;
    bool public blacklistEnabled;
    uint256 public blacklistDuration = 10 minutes;
    uint256 public blacklistTime;
    uint256 public blacklistAmount;

    event ExcludeFromFees(address indexed account, bool isExcluded);

    constructor(string memory name, string memory symbol)
        Token(name, symbol)
    {
        excludeFromFees(owner(), true);
        
        _mint(_msgSender(), maxSupply.sub(amountFarm).sub(amountPlayToEarn));
        
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "Account is already 'excluded'");
        _isExcludedFromFees[account] = excluded;
 
        emit ExcludeFromFees(account, excluded);
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    //Anti bots
    function setBlacklists(address _bots) external onlyOwner {
        require(!bots[_bots]);
        require(_bots!=uniswapV2Pair && _bots!=apeswapV2Pair,"pair address can not be pair");
        require(blacklistTime > block.timestamp,"blacklist is not Enabled");
        bots[_bots] = true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (
            blacklistTime > block.timestamp &&
            amount > blacklistAmount &&
            bots[sender]
        ) {
            revert("You're bot");
        }

        uint256 transferFeeRate = (recipient == uniswapV2Pair || recipient == apeswapV2Pair)
            ? sellFeeRate
            : ((sender == uniswapV2Pair || sender == apeswapV2Pair) ? buyFeeRate : 0);

        if (
            transferFeeRate > 0 &&
            sender != address(this) &&
            recipient != address(this) &&
            !_isExcludedFromFees[sender]
        ) {
            uint256 _fee = amount.mul(transferFeeRate).div(100);
            super._transfer(sender, address(this), _fee);
            amount = amount.sub(_fee);
        }

        super._transfer(sender, recipient, amount);
    }
    function blacklist(uint256 amount) external onlyOwner {
        require(amount > 0, "amount > 0");
        require(!blacklistEnabled);
        
        blacklistAmount = amount;
        blacklistTime = block.timestamp.add(blacklistDuration);
        blacklistEnabled = true;
    }
}