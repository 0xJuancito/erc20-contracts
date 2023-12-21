// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import "./IBaseTokenLogic.sol";

/**
 * @dev interface of the TokenLogic contract
 */
interface IOshiTokenLogic is IBaseTokenLogic {
    // J : バッチ送金に利用する引数の型
    // E : Struct for argument used in "batchTransfer"
    struct BatchObject {
        address recipient;
        uint256 amount;
    }

    // J : トークンを複数のユーザーに一括送金する
    // E : bulk-transfer of this token
    function bulkTransfer(BatchObject[] calldata batchObj) external;
}
