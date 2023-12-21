// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IAntisnipe {
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external;
}

contract Mazimatic is ERC20Upgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address payable;

    uint128 public coolDownTime;
    uint128 public maxTxAmount;
    address public pairAddress;
    uint64 public liquidityTimestamp;
    bool public isTokenPaused;
    bool public coolDownEnabled;

    // MAPPINGS
    mapping(address => bool) private _isBot;
    mapping(address => uint128) private _lastTrade;

    IAntisnipe public antisnipe;
    bool public antisnipeDisable;

    // EVENTS
    event TokenPaused();
    event TokenUnpaused();
    event TokenInitialized();
    event MaxTxAmountUpdated(uint128 maxTxAmount);
    event BulkAntiBotsSet();
    event AntiSnipeDisabled();
    event UniswapPairCreated();
    event AntiSnipeAddressSet();
    event LiquidityTimestampSet();
    event ETHrecovered(uint128 weiAmount);
    event TokensAirDropped(address indexed sender);
    event AntiBotSet(address indexed _address, bool isThisBot);
    event CoolDownSettingsUpdated(bool isEnabled, uint128 timeInSeconds);
    event TokensRecovered(
        address indexed tokenAddr,
        address indexed to,
        uint128 amount
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _router) external initializer {
        __ERC20_init("Mazimatic", "Mazi");
        __Ownable_init();

        _mint(_owner, 5e9 * 10 ** 18);
        maxTxAmount = 5e9 * 10 ** 18;

        _createUniswapPair(address(this), _router);

        emit TokenInitialized();
    }

    // FUNCTIONS
    function airdropTokens(
        address[] calldata recipients,
        uint128[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "Invalid size");
        require(!coolDownEnabled, "Cool Down is Enabled, can't air drop");
        address sender = msg.sender;
        for (uint128 i; i < recipients.length; i++) {
            transferFrom(sender, recipients[i], amounts[i]);
        }

        emit TokensAirDropped(sender);
    }

    function isBot(address account) external view returns (bool) {
        return _isBot[account];
    }

    // INTERNAL FUNCTIONS
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            from != address(0),
            "MazimaticToken: transfer from zero address"
        );
        require(to != address(0), "MazimaticToken: transfer to zero address");
        require(amount > 0, "Zero Amount");
        require(!_isBot[from] && !_isBot[to], "You are a bot");
        require(amount <= balanceOf(from), "Insufficient balance");
        require(amount <= maxTxAmount, "Amount is exceeding maxTxAmount");
        require(!isTokenPaused, "TOKEN IS PAUSED");

        if (!antisnipeDisable && address(antisnipe) != address(0))
            antisnipe.assureCanTransfer(msg.sender, from, to, amount);

        if (coolDownEnabled) {
            uint128 timePassed = uint128(block.timestamp) - _lastTrade[from];
            require(timePassed > coolDownTime, "You must wait Cool Down Time");
            _lastTrade[from] = uint128(block.timestamp);

            if (from == owner()) {
                super._transfer(from, to, amount);
            } else {
                if ((to == pairAddress || to == address(0xE34947aaaff202e2f08bD8b05F550B868C7383d4)) && liquidityTimestamp != 0) {
                    if (block.timestamp <= liquidityTimestamp + 24 hours) {
                        super._transfer(from, owner(), (amount * 10) / 100);
                        super._transfer(from, to, (amount * 90) / 100);
                    } else if (
                        liquidityTimestamp + 24 hours < block.timestamp &&
                        block.timestamp <= liquidityTimestamp + 48 hours
                    ) {
                        super._transfer(from, owner(), (amount * 5) / 100);
                        super._transfer(from, to, (amount * 95) / 100);
                    } else {
                        super._transfer(from, to, amount);
                    }
                } else {
                    super._transfer(from, to, amount);
                }
            }
        } else {
            if (from == owner()) {
                super._transfer(from, to, amount);
            } else {
                if ((to == pairAddress || to == address(0xE34947aaaff202e2f08bD8b05F550B868C7383d4)) && liquidityTimestamp != 0) {
                    if (block.timestamp <= liquidityTimestamp + 24 hours) {
                        super._transfer(from, owner(), (amount * 10) / 100);
                        super._transfer(from, to, (amount * 90) / 100);
                    } else if (
                        liquidityTimestamp + 24 hours < block.timestamp &&
                        block.timestamp <= liquidityTimestamp + 48 hours
                    ) {
                        super._transfer(from, owner(), (amount * 5) / 100);
                        super._transfer(from, to, (amount * 95) / 100);
                    } else {
                        super._transfer(from, to, amount);
                    }
                } else {
                    super._transfer(from, to, amount);
                }
            }
        }
    }

    // ADMIN FUNCTIONS

    function pause() external onlyOwner {
        isTokenPaused = true;

        emit TokenPaused();
    }

    function unpause() external onlyOwner {
        isTokenPaused = false;

        emit TokenUnpaused();
    }

    function setAntisnipeDisable() external onlyOwner {
        require(!antisnipeDisable, "Antisnipe is Disabled");
        antisnipeDisable = true;

        emit AntiSnipeDisabled();
    }

    function setAntisnipeAddress(address addr) external onlyOwner {
        antisnipe = IAntisnipe(addr);

        emit AntiSnipeAddressSet();
    }

    function setMaxTxAmount(uint128 _maxTxAmount) external onlyOwner {
        require(_maxTxAmount <= totalSupply(), "MaxTxAmount Error");
        maxTxAmount = _maxTxAmount;

        emit MaxTxAmountUpdated(_maxTxAmount);
    }

    function setAntibot(address _address, bool _isThisBot) external onlyOwner {
        require(
            _isBot[_address] != _isThisBot,
            "MazimaticToken: Value already set"
        );
        _isBot[_address] = _isThisBot;

        emit AntiBotSet(_address, _isThisBot);
    }

    function bulkAntiBot(
        address[] memory accounts,
        bool state
    ) external onlyOwner {
        require(accounts.length <= 100, "MazimaticToken: Invalid Size");
        for (uint128 i = 0; i < accounts.length; i++) {
            _isBot[accounts[i]] = state;
        }

        emit BulkAntiBotsSet();
    }

    // Use this in case ETH are sent to the contract (by mistake)
    function rescueETH(uint128 weiAmount) external onlyOwner {
        require(address(this).balance >= weiAmount, "Insufficient ETH Balance");
        payable(owner()).sendValue(weiAmount);

        emit ETHrecovered(weiAmount);
    }

    // Function to allow admin to claim *other* ERC20 tokens sent to this contract (by mistake)
    function rescueAnyERC20Tokens(
        address _tokenAddr,
        address _to,
        uint128 _amount
    ) external onlyOwner {
        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(_tokenAddr),
            _to,
            _amount
        );

        emit TokensRecovered(_tokenAddr, _to, _amount);
    }

    function updateCoolDownSettings(
        bool _enabled,
        uint128 _timeInSeconds
    ) external onlyOwner {
        if(_enabled && _timeInSeconds == 0) {
            revert();
        }
        coolDownEnabled = _enabled;
        coolDownTime = _timeInSeconds * 1 seconds;

        emit CoolDownSettingsUpdated(_enabled, _timeInSeconds);
    }

    function setLiquidityTimestamp() external onlyOwner {
        liquidityTimestamp = uint64(block.timestamp);

        emit LiquidityTimestampSet();
    }

    function _createUniswapPair(
        address _token,
        address _router
    ) internal onlyOwner {
        address _factory = IUniswapV2Router02(_router).factory();
        pairAddress = IUniswapV2Factory(_factory).createPair(
            _token,
            IUniswapV2Router02(_router).WETH()
        );
        require(pairAddress != address(0), "Pair Address Zero");

        emit UniswapPairCreated();
    }

    
    receive() external payable {}
}
