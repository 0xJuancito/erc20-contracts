// SPDX-License-Identifier: MIT
/*
      db          `7MMF'    `YMM'   `MP'
     ;MM:           MM        VMb.  ,P
    ,V^MM.          IM         `MM.M'
   ,M  `MM          MM           MMb
   AbmmmqMA         MM         ,M'`Mb.
  A'     VML        MM        ,P   `MM.
.AMA.   .AMMA.    .JMML.    .MM:.  .:MMa.

AIgentX 🤖🧠: An innovative AI Ecosystem Enabling Improved Engagement and Project Oversight.

AIgentX is a dynamic AI ecosystem that harnesses advanced AI and ML technologies.
It utilizes custom business and project data to provide detailed, natural language responses, optimizing interactions,
and reducing costs while offering comprehensive AI solutions for businesses and
projects across platforms like Telegram and Discord. This ecosystem empowers users to create personalized AI
for improved community engagement, accurate project representation, customer satisfaction and sales growth.


Socials:
📝Twitter: https://twitter.com/0xAIgentx
✉️Telegram: https://t.me/+hWMgnOdPhG40Nzhl
🌐Website: https://aigentx.xyz/
📰Whitepaper: https://aigentx.gitbook.io/whitepaper/
📰Medium: https://medium.com/@0xaigentx
*/

pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title AIX Token Contract
 */
contract AIX is IERC20Metadata, Ownable, ERC20 {
    /**
     * Sniper Bot and Malicious Actor Protection during the launch stage:
     * The AIX token employs strategies against sniper bots and malicious users:
     *
     * 1. Selling Fee:
     * - Temporarily sets a 100% selling fee to prevent buying from sniper-bots.
     * - After the launch, disabled by the owner, this cannot be reactivated.
     *
     * 2. Blacklist:
     * - During the launch addresses can be blacklisted.
     * - After the launch, blacklisting is permanently disabled.
     *
     * These mechanisms promote price stability and protect genuine investors.
     *
     * After the launch stage:
     * - Users cannot be blacklisted.
     * - buyFee and sellFee must be <= 5%.
     */

    /// @notice Emitted when a liquidity pool pair is updated.
    event LPPairSet(address indexed pair, bool enabled);

    /// @notice Emitted when an account is marked or unmarked as a liquidity holder (treasury, staking, etc).
    event LiquidityHolderSet(address indexed account, bool flag);

    /// @notice Emitted (once) when fees are locked forever.
    event FeesLockedForever();

    /// @notice Emitted (once) when sniper bot protection is disabled forever.
    event SniperBotProtectionDisabledForever();

    event BlacklistSet(address indexed account, bool flag);

    /// @notice Emitted (once) when blacklist add is restricted forever.
    event BlacklistAddRestrictedForever();

    event BuyFeeNumeratorSet(uint256 value);
    event SellFeeNumeratorSet(uint256 value);
    event TreasurySet(address treasury);
    event BuyFeePaid(address indexed from, address indexed to, uint256 amount);
    event SellFeePaid(address indexed from, address indexed to, uint256 amount);

    /**
     * @dev Struct to group account-specific flags to optimize storage usage.
     * This design pattern leverages Solidity's storage layout, where multiple
     * state variables of the same type are packed into a single storage slot
     * to minimize gas costs.
     *
     *   +-------------------- bytes32 slot ------------------------------+
     *   | 0 | 0 | 0 | ... | isBlackListed | isLiquidityHolder | isLPPool |
     *   +----------------------------------------------------------------+
     *
     * For a deeper understanding of storage packing and its benefits, you can refer to:
     * - https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
     * - https://dev.to/web3_ruud/advance-soliditymastering-storage-slot-c38
     */
    struct AccountInfo {
        bool isLPPool;
        bool isLiquidityHolder;
        bool isBlackListed;
    }
    mapping (address => AccountInfo) public accountInfo;

    string constant private _name = "AIgentX";
    string constant private _symbol = "AIX";
    uint256 constant private TOTAL_SUPPLY = 100_000_000 * (10 ** 18);

    uint256 constant public DENOMINATOR = 10000;
    uint256 constant public MAX_BUY_FEE_NUMERATOR = 500;  // 5%
    uint256 constant public MAX_SELL_FEE_NUMERATOR = 500;  // 5%
    uint256 public buyFeeNumerator;
    uint256 public _sellFeeNumerator;
    address public treasury;
    bool public feesAreLockedForever;
    bool public sniperBotProtectionDisabledForever;
    bool public blacklistAddRestrictedForever;

    constructor(
        address _treasury,
        uint256 _buyFeeNumeratorValue,
        uint256 _sellFeeNumeratorValue
    ) Ownable() ERC20(_name, _symbol) {
        _mint(msg.sender, TOTAL_SUPPLY);
        setLiquidityHolder(msg.sender, true);
        setLiquidityHolder(_treasury, true);
        setTreasury(_treasury);
        setBuyFeeNumerator(_buyFeeNumeratorValue);
        setSellFeeNumerator(_sellFeeNumeratorValue);
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(_treasury != address(0), "Treasury address cannot be zero");
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    function lockFeesForever() external onlyOwner {
        require(!feesAreLockedForever, "already set");
        feesAreLockedForever = true;
        emit FeesLockedForever();
    }

    function restrictBlacklistAddForever() external onlyOwner {
        require(!blacklistAddRestrictedForever, "already set");
        blacklistAddRestrictedForever = true;
        emit BlacklistAddRestrictedForever();
    }

    function setLpPair(address pair, bool enabled) external onlyOwner {
        accountInfo[pair].isLPPool = enabled;
        emit LPPairSet(pair, enabled);
    }

    function setBlacklisted(address account, bool isBlacklisted) external onlyOwner {
        if (isBlacklisted) {
            require(!blacklistAddRestrictedForever, "Blacklist add restricted forever");
        }
        accountInfo[account].isBlackListed = isBlacklisted;
        emit BlacklistSet(account, isBlacklisted);
    }

    function setBuyFeeNumerator(uint256 value) public onlyOwner {
        require(!feesAreLockedForever, "Fees are locked forever");
        require(value <= MAX_BUY_FEE_NUMERATOR, "Exceeds maximum buy fee");
        buyFeeNumerator = value;
        emit BuyFeeNumeratorSet(value);
    }

    function setSellFeeNumerator(uint256 value) public onlyOwner {
        require(!feesAreLockedForever, "Fees are locked forever");
        require(value <= MAX_SELL_FEE_NUMERATOR, "Exceeds maximum buy fee");
        _sellFeeNumerator = value;
        emit SellFeeNumeratorSet(value);
    }

    function sellFeeNumerator() public view returns(uint256) {
        if (sniperBotProtectionDisabledForever) {
            return _sellFeeNumerator;
        }
        return DENOMINATOR;  // 100% to prevent sniper bots from buying
    }

    function disableSniperBotProtectionForever() external onlyOwner {
        require(!sniperBotProtectionDisabledForever, "already set");
        sniperBotProtectionDisabledForever = true;
        emit SniperBotProtectionDisabledForever();
    }

    function setLiquidityHolder(address account, bool flag) public onlyOwner {
        accountInfo[account].isLiquidityHolder = flag;
        emit LiquidityHolderSet(account, flag);
    }

    function _hasLimits(AccountInfo memory fromInfo, AccountInfo memory toInfo) internal pure returns(bool) {
        return !fromInfo.isLiquidityHolder && !toInfo.isLiquidityHolder;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        AccountInfo memory fromInfo = accountInfo[from];
        AccountInfo memory toInfo = accountInfo[to];

        require(!fromInfo.isBlackListed && !toInfo.isBlackListed, "Blacklisted");

        if (!_hasLimits(fromInfo, toInfo) ||
            (fromInfo.isLPPool && toInfo.isLPPool)  // no fee for transferring between pools
        ) {
            super._transfer(from, to, amount);
            return;
        }

        if (fromInfo.isLPPool) {
            // buy
            uint256 buyFeeAmount = amount * buyFeeNumerator / DENOMINATOR;
            emit BuyFeePaid(from, treasury, buyFeeAmount);
            super._transfer(from, treasury, buyFeeAmount);
            unchecked {  // underflow is not possible
                amount -= buyFeeAmount;
            }
        } else if (toInfo.isLPPool) {
            // sell
            uint256 sellFeeAmount = amount * sellFeeNumerator() / DENOMINATOR;
            emit SellFeePaid(from, treasury, sellFeeAmount);
            super._transfer(from, treasury, sellFeeAmount);
            unchecked {  // underflow is not possible
                amount -= sellFeeAmount;
            }
        } else {
            // no fees for usual transfers
        }

        super._transfer(from, to, amount);
    }
}

