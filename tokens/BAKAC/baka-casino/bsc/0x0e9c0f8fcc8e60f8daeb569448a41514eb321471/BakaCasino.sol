// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

interface ManagerInterface {
    function onlySupporter(address sender) external view returns (bool);
}

interface IBakaCasino {
    function claim2() external payable;

    function claim3() external payable;
}

contract BakaCasino is IBakaCasino, ERC20, Ownable {
    using SafeMath for uint256;

    uint256 MAX_TOKEN_TOTAL_SUPPLY = 900 * 10 ** 21;
    uint256 MAX_TOKEN_AIR_DROP = 624 * 10 ** 21;
    uint256 MAX_TOKEN_LP = 135 * 10 ** 21;
    uint256 MAX_TOKEN_LISTING = 45 * 10 ** 21;
    uint256 MAX_TOKEN_GAME_OWNER = 96 * 10 ** 21;

    address AIRDROP_ADDRESS_1 = 0xBBc58aBB75b0efaa3B1e0F0229cc5de530f20701;
    address AIRDROP_ADDRESS_2 = 0x7bcb00f93c344756B02d1ccCF27cB34a8723569a;
    address AIRDROP_ADDRESS_3 = 0xfD1a218842294c5B6D977CC6fcE09C80394B9B53;
    address AIRDROP_ADDRESS = 0xDa75Cf518b2e7F6D08195c24926044B4773D6979;
    address LISTING_ADDRESS = 0xa0bA4ebDF2De553909dF95464C09C1C879015567;
    address LP_ADDRESS = 0x039275fF5a1A92c78aF4Fb30fC3D14dc3C93bCD4;
    address GAME_OWNER_ADDRESS = 0x172e427dF0d49392A4D8D31bc8306B7d39D4fE65;
    // For Support Address
    address SUPPORTER_ADDRESS = 0x140839dAdD906EFF2d0d453D2a2fBD51BFd661ca;

    // 43.200.000 BAKA / Day
    uint256 MAX_AIR_DROP_ROUND_2 = 216 * 10 ** 21;
    uint256 CLAIM_AMOUNT_PER_DAY_2 = 432 * 10 ** 14;
    uint256 MAX_ADDRESS_ROUND_2 = 100_000;

    // 28.800.000 BAKA / Day
    uint256 MAX_AIR_DROP_ROUND_3 = 216 * 10 ** 21;
    uint256 CLAIM_AMOUNT_PER_DAY_3 = 288 * 10 ** 14;
    uint256 MAX_ADDRESS_ROUND_3 = 150_000;

    uint256 totalTokenAirdrop2 = MAX_AIR_DROP_ROUND_2;
    uint256 totalTokenAirdrop3 = MAX_AIR_DROP_ROUND_3;

    address[] private maxAddressPerDay;
    mapping(address => bool) private existedAddressPerDay;

    address[] private totalAirdropAddresses2;
    address[] private totalAirdropAddresses3;
    address private _support;
    uint256 private _feeAmount = 16 * 10 ** 14;

    constructor() ERC20("Baka Casino", "BAKAC") {
        _mint(AIRDROP_ADDRESS, MAX_TOKEN_AIR_DROP);
        _mint(LISTING_ADDRESS, MAX_TOKEN_LISTING);
        _mint(LP_ADDRESS, MAX_TOKEN_LP);
        _mint(GAME_OWNER_ADDRESS, MAX_TOKEN_GAME_OWNER);

        setSupporter(SUPPORTER_ADDRESS);
    }

    /**
     * Set an address of the gameplay management contract.
     */
    function setSupporter(address _manager) public onlyOwner {
        _support = _manager;
    }

    modifier onlySupporter() {
        require(_support == _msgSender(), "Caller is not supporter");
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    // A function modifier to check if the sender has enough balance
    modifier hasBalance(uint256 _amount) {
        require(msg.value >= _amount, "Insufficient balance");
        _;
    }

    /**
     * Transfer to many address
     */
    function transferMany(address[] memory recipients, uint256 amount) public {
        for (uint256 i = 0; i < recipients.length; i++) {
            super._transfer(_msgSender(), recipients[i], amount);
        }
    }

    /**
     * Transfer many address with different amount
     */
    function transferManyWithMultipleAmount(
        address[] memory recipients,
        uint256[] memory amounts
    ) public {
        for (uint256 i = 0; i < recipients.length; i++) {
            super._transfer(_msgSender(), recipients[i], amounts[i]);
        }
    }

    /**
     * Execute airdrop
     */
    function baseClaim(
        address fromAddress,
        uint256 amount,
        address[] storage maxAddressAirdrop,
        uint256 totalAirdropToken,
        uint256 maxAirdropAddressSize
    ) private {
        // Check exists address per day
        require(
            !existedAddressPerDay[_msgSender()],
            "This address claimed airdrop today"
        );
        // If address not exist in airdrop program
        require(
            maxAddressAirdrop.length < maxAirdropAddressSize,
            "The total airdrops is maximum in this airdrop round."
        );
        require(
            maxAddressPerDay.length < maxAirdropAddressSize,
            "The list of airdrops is maximum today."
        );
        require(
            totalAirdropToken > amount,
            "The airdrop amount is exhausted in this round"
        );

        super._transfer(fromAddress, _msgSender(), amount);
        totalAirdropToken = totalAirdropToken - amount;

        maxAddressPerDay.push(_msgSender());
        maxAddressAirdrop.push(_msgSender());
        existedAddressPerDay[_msgSender()] = true;
    }

    function claim2() public payable override hasBalance(_feeAmount) {
        baseClaim(
            AIRDROP_ADDRESS_2,
            CLAIM_AMOUNT_PER_DAY_2,
            totalAirdropAddresses2,
            totalTokenAirdrop2,
            MAX_ADDRESS_ROUND_2
        );
    }

    function claim3() public payable override hasBalance(_feeAmount) {
        baseClaim(
            AIRDROP_ADDRESS_3,
            CLAIM_AMOUNT_PER_DAY_3,
            totalAirdropAddresses3,
            totalTokenAirdrop3,
            MAX_ADDRESS_ROUND_3
        );
    }

    function resetClaim() public onlySupporter {
        uint256 i = 0;
        for (; i < maxAddressPerDay.length; i++) {
            existedAddressPerDay[maxAddressPerDay[i]] = false;
        }
        delete maxAddressPerDay;
    }

    function burn(address account, uint256 amount) public onlySupporter {
        require(
            account == AIRDROP_ADDRESS_1,
            "This address is not the airdrop"
        );
        require(
            account == AIRDROP_ADDRESS_2,
            "This address is not the airdrop"
        );
        require(
            account == AIRDROP_ADDRESS_3,
            "This address is not the airdrop"
        );
        super._burn(account, amount);
    }

    // Use transfer method to withdraw an amount of money and for updating automatically the balance
    function withdrawBalance(address _to, uint256 _value) public onlySupporter {
        payable(_to).transfer(_value);
    }
}
