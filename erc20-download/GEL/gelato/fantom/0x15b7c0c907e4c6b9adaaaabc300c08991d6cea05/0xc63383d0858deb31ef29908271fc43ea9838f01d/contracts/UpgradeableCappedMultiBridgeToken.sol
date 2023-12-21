// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// solhint-disable max-line-length
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
// solhint-enable max-line-length
import {
    IUpgradeableCappedMultiBridgeToken
} from "./interfaces/IUpgradeableCappedMultiBridgeToken.sol";
import {Proxied} from "./vendor/proxy/Proxied.sol";

abstract contract UpgradeableCappedMultiBridgeToken is
    IUpgradeableCappedMultiBridgeToken,
    Proxied,
    ERC20PermitUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public epoch;
    uint256 public epochLength;
    mapping(address => Supply) private _supply;
    EnumerableSet.AddressSet private _bridges;

    event BridgeSupplyCapUpdated(
        address indexed bridge,
        uint256 indexed supplyCap
    );
    event BridgeSupplyEpochTotalUpdated(
        address indexed bridge,
        uint256 indexed supplyTotal
    );
    event EpochLengthUpdated(uint256 epochLength);
    event LogMinted(
        address indexed bridge,
        address indexed to,
        uint256 indexed amount,
        uint256 epochTotalLeft
    );
    event LogBurned(
        address indexed bridge,
        address indexed to,
        uint256 indexed amount
    );

    modifier onlyBridges(address _bridge) {
        require(_bridges.contains(_bridge), "Only Bridges");

        _;
    }

    function updateBridgeSupplyCap(address _bridge, uint256 _cap)
        external
        onlyProxyAdmin
    {
        _supply[_bridge].cap = _cap;

        if (_cap > 0) {
            _bridges.add(_bridge);
        } else {
            _bridges.remove(_bridge);
        }

        emit BridgeSupplyCapUpdated(_bridge, _cap);
    }

    function updateBridgeEpochTotal(address _bridge, uint256 _epochTotal)
        external
        onlyProxyAdmin
    {
        Supply memory b = _supply[_bridge];

        require(b.cap >= _epochTotal, "Total higher than cap");

        _supply[_bridge].epochTotal = _epochTotal;

        emit BridgeSupplyEpochTotalUpdated(_bridge, _epochTotal);
    }

    ///@dev Updating epoch length potentially resets total for all bridges
    function updateEpochLength(uint256 _epochLength) external onlyProxyAdmin {
        require(_epochLength != 0, "Epoch length zero");

        epochLength = _epochLength;

        emit EpochLengthUpdated(_epochLength);
    }

    function mint(address _to, uint256 _amount)
        external
        onlyBridges(msg.sender)
        returns (bool)
    {
        // solhint-disable-next-line not-rely-on-time
        uint256 currentEpoch = block.timestamp / epochLength;

        _supply[msg.sender].total += _amount;

        if (currentEpoch == epoch) {
            _supply[msg.sender].epochTotal += _amount;
        } else {
            epoch = currentEpoch;
            _supply[msg.sender].epochTotal = _amount;
        }

        Supply memory b = _supply[msg.sender];

        require(b.epochTotal <= b.cap, "Epoch mint cap exceeded");

        _mint(_to, _amount);

        emit LogMinted(msg.sender, _to, _amount, b.cap - b.epochTotal);

        return true;
    }

    ///@notice Bridges have to be approved by holders to burn
    function burn(address _from, uint256 _amount)
        external
        onlyBridges(msg.sender)
        returns (bool)
    {
        require(
            _supply[msg.sender].total >= _amount,
            "Execeeds bridge minted amount"
        );

        _supply[msg.sender].total -= _amount;

        _burnFrom(_from, _amount);

        emit LogBurned(msg.sender, _from, _amount);

        return true;
    }

    function supply(address _bridge) external view returns (Supply memory) {
        return _supply[_bridge];
    }

    function bridgeEpochTotalLeft(address _bridge)
        external
        view
        returns (uint256)
    {
        Supply memory b = _supply[_bridge];
        uint256 totalLeft = b.cap - b.epochTotal;
        return totalLeft;
    }

    function isBridge(address _bridge) external view returns (bool) {
        return _bridges.contains(_bridge);
    }

    function bridges() external view returns (address[] memory) {
        uint256 length = _bridges.length();

        address[] memory allBridges = new address[](length);

        for (uint256 i; i < length; i++) {
            allBridges[i] = _bridges.at(i);
        }

        return allBridges;
    }

    function numberOfBridges() external view returns (uint256) {
        return _bridges.length();
    }

    function timeUntilNextEpoch() external view returns (uint256) {
        // solhint-disable not-rely-on-time
        uint256 _epochLength = epochLength;
        uint256 nextEpoch = 1 + (block.timestamp / _epochLength);
        return nextEpoch * _epochLength - block.timestamp;
        // solhint-enable not-rely-on-time
    }

    // solhint-disable-next-line func-name-mixedcase
    function __UpgradeableCappedMultiBridgeToken_init(
        string calldata _name,
        string calldata _symbol,
        uint256 _epochLength
    ) internal onlyInitializing {
        require(_epochLength != 0, "Epoch length zero");

        epochLength = _epochLength;

        __ERC20Permit_init(_name);
        __ERC20_init(_name, _symbol);
    }

    function _burnFrom(address _from, uint256 _amount) private {
        _spendAllowance(_from, msg.sender, _amount);
        _burn(_from, _amount);
    }
}
