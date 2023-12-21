// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@strategy/IStrategy.sol";
import "@vault/FeeOracle.sol";

contract AddressRegistry is OwnableUpgradeable {
    /// FeeOracle
    FeeOracle public feeOracle;
    /// Router
    address public router;
    /// Mapping for coin and its support strategy
    mapping(address => IStrategy[]) public coinToStrategy;
    /// Mapping for strategy and its whitelisted status indicated by timestamp
    mapping(IStrategy => uint256) public strategyWhitelist;
    /// Mapping for rebalancer and its whitelisted status indicated by timestamp
    mapping(address => uint256) public rebalancerWhitelist;
    /// Array of supported coins
    address[] public supportedCoinAddresses;

    event SetRouter(address indexed router);
    event AddStrategy(IStrategy indexed strategy, address[] indexed coins);
    event AddRebalancer(address indexed rebalancer);
    event RemoveStrategy(IStrategy indexed strategy);
    event RemoveRebalancer(address indexed rebalancer);
    event Initialized(address indexed feeOracle, address indexed router);

    constructor() {
        _disableInitializers();
    }

    function init(FeeOracle _feeOracle, address _router) external initializer {
        require(
            address(_feeOracle) != address(0),
            "_feeOracle address can't be zero"
        );
        require(_router != address(0), "_router address can't be zero");

        __Ownable_init();
        feeOracle = _feeOracle;
        router = _router;
        emit Initialized(address(_feeOracle), _router);
    }

    /// @notice Set router
    /// @param _router address of router
    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "_router address can't be zero");
        router = _router;

        emit SetRouter(_router);
    }

    /// @notice Add strategy for given coins
    /// @param strategy address of strategy
    /// @param coins array of coins that strategy supports
    function addStrategy(
        IStrategy strategy,
        address[] calldata coins
    ) external onlyOwner {
        require(
            strategyWhitelist[strategy] == 0,
            "Strategy already whitelisted"
        );
        for (uint256 i; i < coins.length; ) {
            IStrategy[] memory strategiesForCoin = coinToStrategy[coins[i]];
            uint256 j;
            /// check strategy is already registered for the coin
            for (; j < strategiesForCoin.length; j++) {
                if (address(strategiesForCoin[j]) == address(strategy)) break;
            }
            /// add strategy if it's not registered
            if (j == strategiesForCoin.length) {
                coinToStrategy[coins[i]].push(strategy);
            }
            uint256 supportedCoinLength = supportedCoinAddresses.length;
            for (j = 0; j < supportedCoinLength; j++) {
                if (supportedCoinAddresses[j] != coins[i]) {
                    supportedCoinAddresses.push(coins[i]);
                    break;
                }
            }
            unchecked {
                i++;
            }
        }
        strategyWhitelist[strategy] = block.timestamp;

        emit AddStrategy(strategy, coins);
    }

    /// @notice Add rebalancer
    /// @param rebalancer address of rebalancer
    function addRebalancer(address rebalancer) external onlyOwner {
        require(
            rebalancerWhitelist[rebalancer] == 0,
            "Rebalancer already whitelisted"
        );
        rebalancerWhitelist[rebalancer] = block.timestamp;

        emit AddRebalancer(rebalancer);
    }

    /// @notice Remove strategy and remove all coins that supported by removed strategy
    /// @param strategy address of strategy
    function removeStrategy(IStrategy strategy) external onlyOwner {
        require(strategyWhitelist[strategy] != 0, "Strategy not whitelisted");
        strategyWhitelist[strategy] = 0;

        address[] memory coins = supportedCoinAddresses;
        uint256 coinLength = coins.length;
        for (uint8 i; i < coinLength; i++) {
            IStrategy[] storage _strategies = coinToStrategy[coins[i]];
            uint256 strategyLength = _strategies.length;
            for (uint8 j; j < strategyLength; j++) {
                if (_strategies[j] == strategy) {
                    uint256 lastElementIndex = _strategies.length - 1;
                    IStrategy lastElement = _strategies[lastElementIndex];
                    _strategies[j] = lastElement;
                    _strategies.pop();
                    break;
                }
            }
        }

        emit RemoveStrategy(strategy);
    }

    /// @notice Remove rebalancer
    /// @param rebalancer address of rebalancer to be removed
    function removeRebalancer(address rebalancer) external onlyOwner {
        require(
            rebalancerWhitelist[rebalancer] != 0,
            "Rebalancer not whitelisted"
        );
        rebalancerWhitelist[rebalancer] = 0;

        emit RemoveRebalancer(rebalancer);
    }

    /// @notice Get all supported strategies for given coin address
    /// @param coin address of coin
    function getCoinToStrategy(
        address coin
    ) external view returns (IStrategy[] memory strategies) {
        uint256 activeStrategies = 0;
        uint256 strategyLengthForCoin = coinToStrategy[coin].length;
        IStrategy[] memory strategiesForCoin = coinToStrategy[coin];
        // count active strategies
        for (uint256 i; i < strategyLengthForCoin; i++) {
            if (
                strategyWhitelist[strategiesForCoin[i]] < block.timestamp &&
                strategyWhitelist[strategiesForCoin[i]] != 0
            ) {
                activeStrategies++;
            }
        }
        // create array of active strategies
        uint j = 0;
        strategies = new IStrategy[](activeStrategies);
        for (uint256 i; i < strategyLengthForCoin; i++) {
            if (
                strategyWhitelist[strategiesForCoin[i]] < block.timestamp &&
                strategyWhitelist[strategiesForCoin[i]] != 0
            ) {
                strategies[j] = strategiesForCoin[i];
                j++;
            }
        }
    }

    /// @notice Get whitelisted status of given strategy
    /// @param strategy address of strategy
    function isWhitelistedStrategy(
        IStrategy strategy
    ) external view returns (bool) {
        return
            block.timestamp >= strategyWhitelist[strategy] &&
            strategyWhitelist[strategy] != 0;
    }

    /// @notice Get whitelisted status of given rebalancer
    /// @param rebalancer address of rebalancer
    function isWhitelistedRebalancer(
        address rebalancer
    ) external view returns (bool) {
        return
            block.timestamp >= rebalancerWhitelist[rebalancer] &&
            rebalancerWhitelist[rebalancer] != 0;
    }

    function emptyCoinToStrategy(address coin) external onlyOwner {
        delete coinToStrategy[coin];
        require(coinToStrategy[coin].length == 0);
    }
}
