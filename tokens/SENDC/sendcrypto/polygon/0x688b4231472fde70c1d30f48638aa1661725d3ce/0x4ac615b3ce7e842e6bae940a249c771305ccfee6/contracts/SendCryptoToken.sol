// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/ERC777Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./BaseGap.sol";


/**
 * @author Maxim Vasilkov maxim@vasilkoff.com
 * @title  SendCrypto Token
 * @notice name: SENDCRYPTO, symbol: SENDC, owner: https://sendcrypto.com/                                                                               
 *    ____                          ___          ____                                                 
 *   6MMMMb\                        `MM         6MMMMb/                                               
 *  6M'    `                         MM        8P    YM                                /              
 *  MM         ____  ___  __     ____MM       6M      Y ___  __ ____    ___ __ ____   /M      _____   
 *  YM.       6MMMMb `MM 6MMb   6MMMMMM       MM        `MM 6MM `MM(    )M' `M6MMMMb /MMMMM  6MMMMMb  
 *   YMMMMb  6M'  `Mb MMM9 `Mb 6M'  `MM       MM         MM69 "  `Mb    d'   MM'  `Mb MM    6M'   `Mb 
 *       `Mb MM    MM MM'   MM MM    MM       MM         MM'      YM.  ,P    MM    MM MM    MM     MM 
 *        MM MMMMMMMM MM    MM MM    MM       MM         MM        MM  M     MM    MM MM    MM     MM 
 *        MM MM       MM    MM MM    MM       YM      6  MM        `Mbd'     MM    MM MM    MM     MM 
 *  L    ,M9 YM    d9 MM    MM YM.  ,MM        8b    d9  MM         YMP      MM.  ,M9 YM.  ,YM.   ,M9 
 *  MYMMMM9   YMMMM9 _MM_  _MM_ YMMMMMM_        YMMMM9  _MM_         M       MMYMMM9   YMMM9 YMMMMM9  
 *                                                                 d'        MM                       
 *                                                            (8),P          MM                       
 *                                                             YMM          _MM_                      
 *
 * @dev {ERC777} token, including:
 *
 *  - Preminted initial supply
 *  - No access control mechanism (for minting/pausing) and hence no governance
 *  - Max supply limited to 2B tokens
 *  - Premint of 100K tokens to the owner address 
 * 
 */
contract SendCryptoToken is ERC777Upgradeable, OwnableUpgradeable, UUPSUpgradeable, BaseGap {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // stores the amount minted per day
    mapping(uint64 => uint256) private _dailyMinting;

    // timestamp when initialized
    uint256 private _initTime;

    /**
     * @dev 
     */
    function initialize() initializer public {
        // set according to the requirenments the name, the symbol
        address[] memory _defaultOperators; 
        __ERC777_init("SENDCRYPTO", "SENDC", _defaultOperators);
        __Ownable_init();
        __UUPSUpgradeable_init();

        _initTime = block.timestamp;

        // total pre mint is: 36,450,000
        _mint(msg.sender, 36450000 * 10**decimals(),"","");
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * If a send hook is registered for `account`, the corresponding function
     * will be called with the caller address as the `operator` and with
     * `userData` and `operatorData`.
     *
     * See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits {Minted} and {IERC20-Transfer} events.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - if `account` is a contract, it must implement the {IERC777Recipient}
     * interface.
     * - if out of max supplay limit throws "SendCryptoToken: Can not mint over limit"
     * - if out of daily limit throws "SendCryptoToken: Can not mint more today"
     */
    function mint(  address account,
                    uint256 amount) public onlyOwner {

        // a. Can not mint over the limit of maximum supply
        require(amount + totalSupply() <= maxSupply(), "SendCryptoToken: Can not mint over limit");

        // b. Can not mint (limit the speed of tokens supply growth)
        // b.i. too many tokens at once
        // b.ii. in small portions during a short period of time 
        uint256 todayLeft = dailyMintingLimit() - dailyMining(currentDayIndex());
        require(amount <= todayLeft, "SendCryptoToken: Can not mint more today");

        // Update current day mining variable
        _dailyMinting[currentDayIndex()] += amount;

        // not going to be used in minting
        bytes memory userData;
        bytes memory operatorData;

        // it requires account!=address(0)
        _mint(account, amount, userData, operatorData);
    }

    /**
     * @dev Daily minting limit
     *
     * Hardcoded to 252054
     */
    function dailyMintingLimit() public pure virtual returns (uint256) {
        // daily limit mint for total reward - 252,054
        return 252054 * 10**decimals();
    }


    /**
     * @dev gives the current day index from the initialization time
     *
     * 0 for the first day, 1 for the second and so on
     */
    function currentDayIndex() public view virtual returns (uint64) {
        return uint64((block.timestamp - _initTime) / 1 days);
    }


    /**
     * @dev how much minted in the specified day
     *
     * Pass 0 for the first day, 1 for the second and so on
     */
    function dailyMining(uint64 day) public view virtual returns (uint256) {
        return _dailyMinting[day];
    }



    /**
     * @dev according to the specification.
     *
     * Limit of the total supply is 2 billions tokens
     */
    function maxSupply() public pure virtual returns (uint256) {
        return 15 * 10**8 * 10**decimals();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    
}
