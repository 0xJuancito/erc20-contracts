// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HaloToken is ERC20 {
    struct VestingData {
        bool isValidRecipient;
        uint256 claimed;
        uint256 amountTotal;
        uint256 startTimestamp;
        uint256 endTimestamp;
    }

    /// @dev total supply - 0.5 billion
    uint256 private constant CAP = 500_000_000;

    /// @dev 10% of total supply for investment institutions
    uint256 private constant CAP_VC_ONE = 25_000_000;
    uint256 private constant CAP_VC_TWO = 12_500_000;
    uint256 private constant CAP_VC_THREE = 12_500_000;

    /// @dev 35% of total supply for Foundation
    uint256 private constant CAP_FOUNDATION = 175_000_000;

    /// @dev 10% of total supply for Reserve fund
    uint256 private constant CAP_RESERVE_FUND = 50_000_000;

    /// @dev 10% of total supply for Team
    uint256 private constant CAP_TEAM = 50_000_000;

    /// @dev 25% of total supply for Ecosystem operation
    uint256 private constant CAP_ECO_OP = 125_000_000;

    /// @dev 10% of total supply for marketing
    uint256 private constant CAP_MARKETING = 50_000_000;

    // Addresses
    address public constant ADDR_VC_ONE = 0x74e7Ce6e4b77B7688ad2b472CE00f6B7251E2d5a;
    address public constant ADDR_VC_TWO = 0x359A36661792195705c5815b3A9b289c87777777;
    address public constant ADDR_VC_THREE = 0x9CFFeB9aB1398CBA71658F98408C42767f9e5816;
    address public constant ADDR_FOUNDATION = 0x9472648B72CB379E597f85152cB434F8c7D00fd2;
    address public constant ADDR_RESERVE_FUND = 0x3A86daD327a4FfC01B474886D4aB17d642b08eCf;
    address public constant ADDR_TEAM = 0x9198d1Bf9E03505dDf52ae7Ee2FB12CFF6d8C884;
    address public constant ADDR_ECO_OP = 0xEd6b757FD4EBEF724C8Da7Cb00b8F5ceEFe00810;
    address public constant ADDR_MARKETING = 0x1B86c3589764CDb706Aca767B8d98Ad6fcaaaef4;

    mapping(address => VestingData) private vestingDatas;

    uint256 private immutable _tgeTimestamp;

    event Claimed(address indexed recipient, uint256 amount, uint256 timestamp);

    constructor() ERC20("HALO Token", "HALO") {
        _tgeTimestamp = block.timestamp;
        _initVestingData();
    }

    function claim(uint256 amount) public {
        require(vestingDatas[msg.sender].isValidRecipient, "HaloToken: caller is not valid recipient");
        VestingData storage vestingData = vestingDatas[msg.sender];

        require(
            vestingData.claimed + amount <= vestedAmount(msg.sender, block.timestamp),
            "HaloToken: not enough claimable amount"
        );

        vestingData.claimed += amount;
        emit Claimed(msg.sender, amount, block.timestamp);

        _mint(msg.sender, amount);
    }

    function claimAll() external {
        uint256 amount = vestedAmount(msg.sender, block.timestamp) - claimedAmount(msg.sender);
        claim(amount);
    }

    function vestedAmount(address recipient, uint256 timestamp) public view returns (uint256) {
        require(vestingDatas[recipient].isValidRecipient, "HaloToken: invalid recipient");
        require(timestamp >= _tgeTimestamp, "HaloToken: timestamp before TGE timestamp");
        uint256 mulDecimals = 10 ** decimals();

        /// @dev no locking for reserve fund
        if (recipient == ADDR_RESERVE_FUND) {
            return CAP_RESERVE_FUND * mulDecimals;
        }

        /// @dev three phase vesting for marketing
        if (recipient == ADDR_MARKETING) {
            // phase 1: initial supply
            uint256 initialSupply = 8_214_295;
            if (timestamp < _tgeTimestamp + 1 days) {
                return initialSupply * mulDecimals;
            }
            // phase 2: release per day
            uint256 stepSupplyPerDay = 714_285;
            if (timestamp < _tgeTimestamp + 14 days) {
                uint256 steps = (timestamp - _tgeTimestamp) / 1 days;
                return (initialSupply + stepSupplyPerDay * steps) * mulDecimals;
            }
            uint256 accumulated = initialSupply + stepSupplyPerDay * 13; // 17_500_000
            if (timestamp < _tgeTimestamp + 30 days) {
                return accumulated * mulDecimals;
            }
            // phase 3: linear vesting
            uint256 startTimestamp = _tgeTimestamp + 30 days;
            uint256 endTimestamp = _tgeTimestamp + 1830 days;
            if (timestamp < endTimestamp) {
                return mulDecimals * accumulated
                    + mulDecimals * (CAP_MARKETING - accumulated) * (timestamp - startTimestamp)
                        / (endTimestamp - startTimestamp);
            }

            return CAP_MARKETING * mulDecimals;
        }

        /// @dev linear vesting for other recipients
        VestingData memory vestingData = vestingDatas[recipient];
        if (timestamp < vestingData.startTimestamp) {
            return 0;
        }
        if (timestamp < vestingData.endTimestamp) {
            return mulDecimals * vestingData.amountTotal * (timestamp - vestingData.startTimestamp)
                / (vestingData.endTimestamp - vestingData.startTimestamp);
        }
        return vestingData.amountTotal * mulDecimals;
    }

    function claimedAmount(address recipient) public view returns (uint256) {
        require(vestingDatas[recipient].isValidRecipient, "HaloToken: invalid recipient");

        return vestingDatas[recipient].claimed;
    }

    function cap() external view returns (uint256) {
        return CAP * 10 ** decimals();
    }

    function tgeTimestamp() external view returns (uint256) {
        return _tgeTimestamp;
    }

    function _initVestingData() private {
        vestingDatas[ADDR_VC_ONE] = VestingData({
            isValidRecipient: true,
            claimed: 0,
            amountTotal: CAP_VC_ONE,
            startTimestamp: _tgeTimestamp + 150 days,
            endTimestamp: _tgeTimestamp + 1050 days
        });

        vestingDatas[ADDR_VC_TWO] = VestingData({
            isValidRecipient: true,
            claimed: 0,
            amountTotal: CAP_VC_TWO,
            startTimestamp: _tgeTimestamp + 60 days,
            endTimestamp: _tgeTimestamp + 960 days
        });

        vestingDatas[ADDR_VC_THREE] = VestingData({
            isValidRecipient: true,
            claimed: 0,
            amountTotal: CAP_VC_THREE,
            startTimestamp: _tgeTimestamp + 60 days,
            endTimestamp: _tgeTimestamp + 960 days
        });

        vestingDatas[ADDR_FOUNDATION] = VestingData({
            isValidRecipient: true,
            claimed: 0,
            amountTotal: CAP_FOUNDATION,
            startTimestamp: _tgeTimestamp + 30 days,
            endTimestamp: _tgeTimestamp + 1830 days
        });

        /// @dev no locking for reserve fund
        vestingDatas[ADDR_RESERVE_FUND] = VestingData({
            isValidRecipient: true,
            claimed: 0,
            amountTotal: CAP_RESERVE_FUND,
            startTimestamp: _tgeTimestamp,
            endTimestamp: _tgeTimestamp
        });

        vestingDatas[ADDR_TEAM] = VestingData({
            isValidRecipient: true,
            claimed: 0,
            amountTotal: CAP_TEAM,
            startTimestamp: _tgeTimestamp + 330 days,
            endTimestamp: _tgeTimestamp + 1230 days
        });

        vestingDatas[ADDR_ECO_OP] = VestingData({
            isValidRecipient: true,
            claimed: 0,
            amountTotal: CAP_ECO_OP,
            startTimestamp: _tgeTimestamp + 30 days,
            endTimestamp: _tgeTimestamp + 1830 days
        });

        /// @dev three phase vesting for marketing:
        vestingDatas[ADDR_MARKETING] = VestingData({
            isValidRecipient: true,
            claimed: 0,
            amountTotal: CAP_MARKETING,
            startTimestamp: _tgeTimestamp,
            endTimestamp: _tgeTimestamp + 1830 days
        });
    }
}
