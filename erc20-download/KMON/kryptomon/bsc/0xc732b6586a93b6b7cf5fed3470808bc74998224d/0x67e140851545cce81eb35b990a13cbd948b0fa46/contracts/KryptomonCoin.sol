// We will be using Solidity version 0.5.3
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
//import "./dependencies_third/@seriality/src/Seriality.sol";
// Import the IERC20 interface and and SafeMath library
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract KryptomonCoin is ERC20Upgradeable, AccessControlUpgradeable{

	using SafeMathUpgradeable for uint256;

	 //We usually require to know who are all the stakeholders.
    address[] internal stakeholders;

    //The stakes for each stakeholder.
    mapping(address => uint256) internal stakes;


    //The accumulated rewards for each stakeholder.
    mapping(address => uint256) internal rewards;
 	
 	function initialize() public initializer{
        __ERC20_init("KmonCoin", "KMON"); 
		_setupRole(DEFAULT_ADMIN_ROLE, 0x8EDF83E1dbA45De7775B8af33A2b5a564194925D);
		_mint(0x8EDF83E1dbA45De7775B8af33A2b5a564194925D, 1000000000000000000000000000);
    }
   
}