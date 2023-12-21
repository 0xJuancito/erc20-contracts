// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

interface IAnkrBond_R1 {

    event CertTokenChanged(address oldCertToken, address newCertToken);

    event OperatorChanged(address oldOperator, address newOperator);

    event PoolContractChanged(address oldPool, address newPool);

    event RatioUpdate(uint256 newRatio);

    event SwapFeeOperatorChanged(address oldSwapFeeOperator, address newSwapFeeOperator);

    event SwapFeeRatioUpdate(uint256 newSwapFeeRatio);

    function balanceToShares(uint256 amount) external view returns (uint256);

    function burnBondsFrom(address from, uint256 amount) external;

    function burnSharesFrom(address from, uint256 shares) external;

    function changeCertToken(address newCertToken) external;

    function changeOperator(address newOperator) external;

    function changePoolContract(address newPool) external;

    function changeSwapFeeOperator(address newSwapFeeOperator) external;

    function initialize(address operator, address pool) external;

    function isRebasing() external pure returns (bool);

    function lockShares(uint256 shares) external;

    function lockSharesFor(address account, uint256 shares) external;

    function mintBondsTo(address to, uint256 amount) external;

    function mintSharesTo(address to, uint256 shares) external;

    function ratio() external view returns (uint256);

    function sharesOf(address account) external view returns (uint256);

    function sharesToBalance(uint256 amount) external view returns (uint256);

    function totalSharesSupply() external view returns (uint256);

    function unlockShares(uint256 shares) external;

    function unlockSharesFor(address account, uint256 bonds) external;

    function updateRatio(uint256 newRatio) external;

    function updateSwapFeeRatio(uint256 newSwapFeeRatio) external;

    function getSwapFeeInBonds(uint256 bonds) external view returns(uint256);

    function getSwapFeeInShares(uint256 shares) external view returns(uint256);
}
