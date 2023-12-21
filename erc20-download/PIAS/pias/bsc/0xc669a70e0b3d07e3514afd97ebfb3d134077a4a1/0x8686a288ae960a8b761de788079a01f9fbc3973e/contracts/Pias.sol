// SPDX-License-Identifier: MPL-2.0
pragma solidity =0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "./interfaces/IPias.sol";

contract Pias is
	UUPSUpgradeable,
	ERC20CappedUpgradeable,
	AccessControlEnumerableUpgradeable,
	IPias
{
	bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

	function initialize() external initializer {
		__UUPSUpgradeable_init();
		__ERC20Capped_init(10_000_000_000_000_000_000_000_000_000);
		__ERC20_init("PIAS", "PIAS");
		__AccessControlEnumerable_init();
		_setupRole(BURNER_ROLE, _msgSender());
		_setupRole(MINTER_ROLE, _msgSender());
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
	}

	function supportsInterface(bytes4 _interfaceId)
		public
		view
		virtual
		override
		returns (bool)
	{
		return
			_interfaceId == type(IPias).interfaceId ||
			_interfaceId == type(IERC20Upgradeable).interfaceId ||
			_interfaceId == type(IERC20MetadataUpgradeable).interfaceId ||
			AccessControlEnumerableUpgradeable.supportsInterface(_interfaceId);
	}

	function mint(address _account, uint256 _amount)
		external
		onlyRole(MINTER_ROLE)
	{
		_mint(_account, _amount);
	}

	function burn(address _account, uint256 _amount)
		external
		onlyRole(BURNER_ROLE)
	{
		_burn(_account, _amount);
	}

	function _authorizeUpgrade(address)
		internal
		override
		onlyRole(DEFAULT_ADMIN_ROLE)
	{}
}
