// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

contract SelfMintingControllerMock {
  struct DaoFee {
    uint256 feePercentage;
    address feeRecipient;
  }

  mapping(address => uint256) private capMint;

  mapping(address => uint256) private capDeposit;

  mapping(address => DaoFee) private fee;

  function setCapMintAmount(
    address selfMintingDerivative,
    uint256 capMintAmount
  ) external {
    _setCapMintAmount(selfMintingDerivative, capMintAmount);
  }

  function setCapDepositRatio(
    address selfMintingDerivative,
    uint256 capDepositRatio
  ) external {
    _setCapDepositRatio(selfMintingDerivative, capDepositRatio);
  }

  function setDaoFee(address selfMintingDerivative, DaoFee calldata daoFee)
    external
  {
    _setDaoFee(selfMintingDerivative, daoFee);
  }

  function getCapMintAmount(address selfMintingDerivative)
    external
    view
    returns (uint256 capMintAmount)
  {
    capMintAmount = capMint[selfMintingDerivative];
  }

  function getCapDepositRatio(address selfMintingDerivative)
    external
    view
    returns (uint256 capDepositRatio)
  {
    capDepositRatio = capDeposit[selfMintingDerivative];
  }

  function getDaoFee(address selfMintingDerivative)
    external
    view
    returns (DaoFee memory daoFee)
  {
    daoFee = fee[selfMintingDerivative];
  }

  function getDaoFeePercentage(address selfMintingDerivative)
    external
    view
    returns (uint256 daoFeePercentage)
  {
    daoFeePercentage = fee[selfMintingDerivative].feePercentage;
  }

  function getDaoFeeRecipient(address selfMintingDerivative)
    external
    view
    returns (address recipient)
  {
    recipient = fee[selfMintingDerivative].feeRecipient;
  }

  function _setCapMintAmount(
    address selfMintingDerivative,
    uint256 capMintAmount
  ) internal {
    require(
      capMint[selfMintingDerivative] != capMintAmount,
      'Cap mint amount is the same'
    );
    capMint[selfMintingDerivative] = capMintAmount;
  }

  function _setCapDepositRatio(
    address selfMintingDerivative,
    uint256 capDepositRatio
  ) internal {
    require(
      capDeposit[selfMintingDerivative] != capDepositRatio,
      'Cap deposit ratio is the same'
    );
    capDeposit[selfMintingDerivative] = capDepositRatio;
  }

  function _setDaoFee(address selfMintingDerivative, DaoFee calldata daoFee)
    internal
  {
    require(
      fee[selfMintingDerivative].feePercentage != daoFee.feePercentage ||
        fee[selfMintingDerivative].feeRecipient != daoFee.feeRecipient,
      'Dao fee is the same'
    );
    fee[selfMintingDerivative] = DaoFee(
      daoFee.feePercentage,
      daoFee.feeRecipient
    );
  }
}
