// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "./ITokenSale.sol";

/**
 * @title IAdmin.
 * @dev interface of Admin contract
 * which can set addresses for contracts for:
 * airdrop, token sales maintainers, staking.
 * Also Admin can create new pool.
 */
interface IAdmin is IAccessControl {
    function getParams(address)
        external
        view
        returns (ITokenSale.Params memory);

    function airdrop() external returns (address);

    function tokenSalesM(address) external returns (bool);

    function blockClaim(address) external returns (bool);

    function tokenSales(uint256) external returns (address);

    function masterTokenSale() external returns (address);

    function stakingContract() external returns (address);

    function setMasterContract(address) external;

    function setAirdrop(address _newAddress) external;

    function setStakingContract(address) external;

    function createPool(ITokenSale.Params calldata _params) external;

    function getTokenSales() external view returns (address[] memory);

    function wallet() external view returns (address);

    function addToBlackList(address, address[] memory) external;

    function blacklist(address, address) external returns (bool);

    function superCharge() external returns(address);

    function setSuperCharge(address) external;

    /**
     * @dev Emitted when pool is created.
     */
    event CreateTokenSale(address instanceAddress);
    /**
     * @dev Emitted when airdrop is set.
     */
    event SetAirdrop(address airdrop);
}
