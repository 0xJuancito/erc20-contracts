// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ICROIDToken.sol";

contract CROIDToken is ICROIDToken, ERC20Permit {
    using Address for address;

    uint256 public constant ONE_YEAR_IN_SECONDS = 31536000; // 60 * 60 * 24 * 365
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 1e18; // 1B
    uint256 public immutable deploymentStartTime;

    constructor(
        address _teamAddress,
        address _airdropAddress,
        address _idoAddress,
        address _marketingAddress,
        address _partershipsAddress,
        address _communityTreasuryAddress,
        address _stakingIncentivesAddress,
        address _liquidityManagementAddress
    ) ERC20("Cronos ID Token", "CROID") ERC20Permit("Cronos ID Token") {
        require(
            _teamAddress.isContract(),
            "CROID: The account of team should be a contract"
        );
        require(
            _airdropAddress != address(0),
            "CROID: The airdrop account should not be empty"
        );
        require(
            _idoAddress != address(0),
            "CROID: The IDO account should not be empty"
        );
        require(
            _marketingAddress != address(0),
            "CROID: The marketing account should not be empty"
        );
        require(
            _partershipsAddress != address(0),
            "CROID: The intergration & partnerships account should not be empty"
        );
        require(
            _communityTreasuryAddress != address(0),
            "CROID: The community treasury account should not be empty"
        );
        require(
            _stakingIncentivesAddress != address(0),
            "CROID: The staking incentives account should not be empty"
        );
        require(
            _liquidityManagementAddress != address(0),
            "CROID: The liquidity management & incentives account should not be empty"
        );

        deploymentStartTime = block.timestamp;

        // --- Initial CROID allocations ---

        // Team: 8%, 36 months linear vesting contract
        uint256 teamEntitlement = (TOTAL_SUPPLY * 80) / 1000;
        _mint(_teamAddress, teamEntitlement);

        // Airdrop: 0.075%
        uint256 airdropEntitlement = (TOTAL_SUPPLY * 75) / 100_000;
        _mint(_airdropAddress, airdropEntitlement);

        // IDO: 0.125%
        uint256 idoEntitlement = (TOTAL_SUPPLY * 125) / 100_000;
        _mint(_idoAddress, idoEntitlement);

        // Marketing: 15%
        uint256 marketingEntitlement = (TOTAL_SUPPLY * 150) / 1000;
        _mint(_marketingAddress, marketingEntitlement);

        // Intergration and Partnerships: 25%
        uint256 partershipsEntitlement = (TOTAL_SUPPLY * 250) / 1000;
        _mint(_partershipsAddress, partershipsEntitlement);

        // Community Treasury: 19.9%
        uint256 communityTreasuryEntitlement = (TOTAL_SUPPLY * 199) / 1000;
        _mint(_communityTreasuryAddress, communityTreasuryEntitlement);

        // Staking Incentives: 7% (Year 1: 2%, Year 2-4: 5%)
        uint256 stakingIncentivesEntitlement = (TOTAL_SUPPLY * 70) / 1000;
        _mint(_stakingIncentivesAddress, stakingIncentivesEntitlement);

        // Liquidity Management & Incentives: 24.9% (Year 1: 10.4%, Year 2-4: 14.5%)
        uint256 liquidityManagementEntitlement = (TOTAL_SUPPLY * 249) / 1000;
        _mint(_liquidityManagementAddress, liquidityManagementEntitlement);
    }

    function getDeploymentStartTime() public view override returns (uint256) {
        return deploymentStartTime;
    }

    function burn(uint256 amount) public override {
        _burn(_msgSender(), amount);
    }

    function isFirstYear() public view returns (bool) {
        return (block.timestamp - deploymentStartTime) < ONE_YEAR_IN_SECONDS;
    }

    function _beforeTokenTransfer(
        address,
        address to,
        uint256
    ) internal view override {
        require(
            to != address(this),
            "CROID: Cannot transfer tokens directly to the CROID token contract"
        );
    }
}
