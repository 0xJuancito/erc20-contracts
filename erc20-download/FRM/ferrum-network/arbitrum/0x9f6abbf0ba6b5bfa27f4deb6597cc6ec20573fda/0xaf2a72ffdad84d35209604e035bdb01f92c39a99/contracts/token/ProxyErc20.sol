// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <=0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

interface IGenericUpgradableToken {
		function init(string memory _name, string memory _symbol,
			uint256 _totalSupply, address owner, address admin) external;
}

interface IGenericUpgradableTokenMintable {
    function updateTotalSupply(address to, uint256 newTotalSupply) external;
}

contract GenericUpgradableToken is ERC20BurnableUpgradeable,
	OwnableUpgradeable, IGenericUpgradableToken {
    using SafeMath for uint256;

		function init(string memory _name, string memory _symbol,
			uint256 _totalSupply, address owner, address admin)
		external override initializer {
			__Context_init_unchained();
			__ERC20_init_unchained(_name, _symbol);
			__ERC20Burnable_init_unchained();
			__Ownable_init_unchained();
			_mint(owner, _totalSupply);
			transferOwnership(admin);
		}
}

contract GenericUpgradableTokenMintable is GenericUpgradableToken, IGenericUpgradableTokenMintable {
    using SafeMath for uint256;

    function updateTotalSupply(address to, uint256 newTotalSupply)
		public override virtual onlyOwner {
			uint256 amount = newTotalSupply.sub(totalSupply());
			_mint(to, amount);
    }
}

contract FerrumProxyTokenDeployer {
	event TokenDeployed(address token, bytes data);
	event ProxyContsuctorArgs(bytes args);
	function deployToken(
		address logic, string memory name, string memory symbol,
		uint256 totalSupply, address admin) external returns (address)
	{
		bytes memory data = abi.encodeWithSelector(IGenericUpgradableToken.init.selector,
			name, symbol, totalSupply, msg.sender, admin
		);
		console.logBytes(data);
		address token = address(new TransparentUpgradeableProxy{
			salt: keccak256(abi.encode(name, symbol, msg.sender))}(
			logic, admin, data
		));
		emit TokenDeployed(token, data);
		bytes memory args = abi.encode(logic, admin, data);
		emit ProxyContsuctorArgs(args);
		return token;
	}

	function updateTotalSupplyMethodData(
		address to, uint256 newTotalSupply
	) external pure returns (bytes memory data) {
		data = abi.encodeWithSelector(IGenericUpgradableTokenMintable.updateTotalSupply.selector,
			to, newTotalSupply);
	}
}