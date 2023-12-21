// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

contract SoilToken is ERC20, ERC20Burnable, ERC20Snapshot, Ownable {
  uint256 constant SUPPLY = 100_000_000 * 10**18;

  /// @dev Event will be emitted when the whitelist of snapshooters is updated
  /// @param caller The address which update the whitelist
  /// @param snapshooters Array of addresses of snapshooters
  /// @param isWhitelisted Whether the snapshooters are whitelisted or not
  event UpdateWhitelistOfSnapshooters(
    address indexed caller,
    address[] snapshooters,
    bool isWhitelisted
  );

  /// @dev Whitelist of addresses allowed to make snapshots
  mapping(address => bool) public whitelistOfSnapshooters;

  /// @dev Constructor of the SoilToken contract
  /// @param contractOwner The owner of the contract
  /// @param initialHolders The array of initial addresses of holders
  /// @param amountsForHolders The array of tokens amount for the holders
  constructor(
    address contractOwner,
    address[] memory initialHolders,
    uint256[] memory amountsForHolders
  ) ERC20("Soil", "SOIL") {
    _transferOwnership(contractOwner);
    uint256 supply = 0;

    require(initialHolders.length == amountsForHolders.length, "Invalid arrays length");
    require(initialHolders.length <= 255, "Array length cannot be greater than 256");
    for (uint8 i = 0; i < initialHolders.length; i++) {
      supply += amountsForHolders[i];
      require(initialHolders[i] != address(0), "Address zero provided");
      _mint(initialHolders[i], amountsForHolders[i]);
    }

    require(supply == SUPPLY, "Supply must be equal to 100 000 000 tokens");
  }

  modifier onlySnapshooter() {
    require(whitelistOfSnapshooters[msg.sender], "Only for the snapshooter");
    _;
  }

  /// @dev Method to making snapshots
  /// @notice It can be called only by whitelisted snapshooter
  function snapshot() external onlySnapshooter {
    _snapshot();
  }

  /// @dev Method to update whitelist of snapshooters
  /// @param snapshooters Array of addresses of snapshooters
  /// @param isWhitelisted Whether the snapshooters are whitelisted or not
  /// @notice It can be called only by owner
  function updateWhitelistOfSnapshooters(address[] calldata snapshooters, bool isWhitelisted)
    external
    onlyOwner
  {
    for (uint256 i = 0; i < snapshooters.length; i++) {
      whitelistOfSnapshooters[snapshooters[i]] = isWhitelisted;
    }

    emit UpdateWhitelistOfSnapshooters(msg.sender, snapshooters, isWhitelisted);
  }

  // The following functions are overrides required by Solidity.

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, ERC20Snapshot) {
    super._beforeTokenTransfer(from, to, amount);
  }
}
