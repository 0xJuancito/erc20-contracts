// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../token-distribution/SaleRounds.sol";

contract GovernanceToken is IERC165, SaleRounds {
    using ERC165Checker for address;

    bytes4 public constant IID_IERC20 = type(IERC20).interfaceId;
    bytes4 public constant IID_IERC165 = type(IERC165).interfaceId;

    uint8 private decimalUnits;

    constructor(string memory _tokenName,
                uint8 _decimalUnits, string memory _tokenSymbol,
                address _gameOwnerAddress, address[] memory _walletAddresses)
                SaleRounds(_tokenName, _tokenSymbol, _decimalUnits, _gameOwnerAddress, _walletAddresses) {
        decimalUnits = _decimalUnits;
    }

    function isERC20() external view returns (bool) {
        return address(this).supportsInterface(IID_IERC20);
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == IID_IERC20 || interfaceId == IID_IERC165;
    }

    function decimals() public view virtual override returns (uint8) {
        return decimalUnits;
    }
}
