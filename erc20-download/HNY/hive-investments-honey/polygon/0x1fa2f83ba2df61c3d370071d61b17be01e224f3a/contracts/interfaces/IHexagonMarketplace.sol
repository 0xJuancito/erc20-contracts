//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;
interface IHexagonMarketplace {

    function getRoyaltiesGenerated(address _collectionAddress, uint _currencyType) external view returns(uint);

}