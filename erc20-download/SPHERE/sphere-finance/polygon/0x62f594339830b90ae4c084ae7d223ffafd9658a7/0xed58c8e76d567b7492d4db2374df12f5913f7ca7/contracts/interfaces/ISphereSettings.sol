// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface ISphereSettings {
  struct BuyFees {
    uint liquidityFee;
    uint treasuryFee;
    uint riskFreeValueFee;
    uint totalFees;
  }

  struct SellFees {
    uint liquidityFee;
    uint treasuryFee;
    uint riskFreeValueFee;
    uint totalFees;
  }

  struct TransferFees {
    uint liquidityFee;
    uint treasuryFee;
    uint riskFreeValueFee;
    uint totalFees;
  }

  struct Fees {
    uint burnFee;
    uint galaxyBondFee;
    uint realFeePartyArray;
    bool isTaxBracketEnabledInMoveFee;
  }

  struct GameFees {
    uint stakeFee;
    uint depositLimit;
  }

  function currentBuyFees() external view returns (BuyFees memory);
  function currentSellFees() external view returns (SellFees memory);
  function currentTransferFees() external view returns (TransferFees memory);
  function currentGameFees() external view returns (GameFees memory);
  function currentFees() external view returns (Fees memory);
  function allCurrentFees() external view returns (
    BuyFees memory,
    SellFees memory,
    GameFees memory,
    Fees memory
  );

  event SetBuyFees(BuyFees fees);
  event SetSellFees(SellFees fees);
  event SetTransferFees(TransferFees fees);
  event SetGameFees(GameFees fees);
  event SetFees(Fees fees);
}
