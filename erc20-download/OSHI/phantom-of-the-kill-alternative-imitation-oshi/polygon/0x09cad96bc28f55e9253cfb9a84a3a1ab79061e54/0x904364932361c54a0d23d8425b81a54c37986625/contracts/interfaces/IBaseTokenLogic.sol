// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev interface of the TokenLogic contract
 */
interface IBaseTokenLogic is IERC20Upgradeable {
    event EditMaxSupply(uint256 newMaxSupply);

    // J : トークンの発行 (onlyOwner)
    // E : issue token (onlyOwner)
    function mint(address account, uint256 amount) external;

    // J : トークンの焼却 (onlyOwner)
    // E : burn token (onlyOwner)
    function burn(uint256 amount) external;

    // J : トークンの最大供給量の確認 (onlyOwner)
    // E : check the "maxSupply" of this token
    function maxSupply() external view returns (uint256);

    // // J : トークンの最大供給量を変更 (onlyOwner)
    // // E : change the "maxSupply" of this token
    // function editMaxSupply(uint256 newMaxSupply) external;
}
