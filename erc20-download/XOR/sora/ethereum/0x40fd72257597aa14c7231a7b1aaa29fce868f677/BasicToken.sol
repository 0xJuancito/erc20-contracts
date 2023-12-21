//! The basic-coin ECR20-compliant token contract.
//!
//! Copyright 2016 Gavin Wood, Parity Technologies Ltd.
//!
//! Licensed under the Apache License, Version 2.0 (the "License");
//! you may not use this file except in compliance with the License.
//! You may obtain a copy of the License at
//!
//!     http://www.apache.org/licenses/LICENSE-2.0
//!
//! Unless required by applicable law or agreed to in writing, software
//! distributed under the License is distributed on an "AS IS" BASIS,
//! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//! See the License for the specific language governing permissions and
//! limitations under the License.

pragma solidity ^0.5.8;

contract Owned {
	modifier only_owner { require(msg.sender == owner); _; }

	event NewOwner(address indexed old, address indexed current);

    function setOwner(address _new) only_owner public { emit NewOwner(owner, _new); owner = _new; }

	address public owner = msg.sender;
}

interface Token {
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);

	function balanceOf(address _owner) view external returns (uint256 balance);
	function transfer(address _to, uint256 _value) external returns (bool success);
	function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
	function approve(address _spender, uint256 _value) external returns (bool success);
	function allowance(address _owner, address _spender) view external returns (uint256 remaining);
}

// TokenReg interface
contract TokenReg {
	function register(address _addr, string memory _tla, uint _base, string memory _name) public payable returns (bool);
	function registerAs(address _addr, string memory _tla, uint _base, string memory _name, address _owner) public payable returns (bool);
	function unregister(uint _id) public;
	function setFee(uint _fee) public;
	function tokenCount() public view returns (uint);
	function token(uint _id) public view returns (address addr, string memory tla, uint base, string memory name, address owner);
	function fromAddress(address _addr) public view returns (uint id, string memory tla, uint base, string memory name, address owner);
	function fromTLA(string memory _tla) public view returns (uint id, address addr, uint base, string memory name, address owner);
	function meta(uint _id, bytes32 _key) public view returns (bytes32);
	function setMeta(uint _id, bytes32 _key, bytes32 _value) public;
	function drain() public;
	uint public fee;
}

// BasicCoin, ECR20 tokens that all belong to the owner for sending around
contract BasicCoin is Owned, Token {
	// this is as basic as can be, only the associated balance & allowances
	struct Account {
		uint balance;
		mapping (address => uint) allowanceOf;
	}

	// the balance should be available
	modifier when_owns(address _owner, uint _amount) {
		if (accounts[_owner].balance < _amount) revert();
		_;
	}

	// an allowance should be available
	modifier when_has_allowance(address _owner, address _spender, uint _amount) {
		if (accounts[_owner].allowanceOf[_spender] < _amount) revert();
		_;
	}



	// a value should be > 0
	modifier when_non_zero(uint _value) {
		if (_value == 0) revert();
		_;
	}

	bool public called = false;

	// the base, tokens denoted in micros
	uint constant public base = 1000000;

	// available token supply
	uint public totalSupply;

	// storage and mapping of all balances & allowances
	mapping (address => Account) accounts;

	// constructor sets the parameters of execution, _totalSupply is all units
	constructor(uint _totalSupply, address _owner) public   when_non_zero(_totalSupply) {
		totalSupply = _totalSupply;
		owner = _owner;
		accounts[_owner].balance = totalSupply;
	}

	// balance of a specific address
	function balanceOf(address _who) public view returns (uint256) {
		return accounts[_who].balance;
	}

	// transfer
	function transfer(address _to, uint256 _value) public   when_owns(msg.sender, _value) returns (bool) {
		emit Transfer(msg.sender, _to, _value);
		accounts[msg.sender].balance -= _value;
		accounts[_to].balance += _value;

		return true;
	}

	// transfer via allowance
	function transferFrom(address _from, address _to, uint256 _value) public   when_owns(_from, _value) when_has_allowance(_from, msg.sender, _value) returns (bool) {
		called = true;
		emit Transfer(_from, _to, _value);
		accounts[_from].allowanceOf[msg.sender] -= _value;
		accounts[_from].balance -= _value;
		accounts[_to].balance += _value;

		return true;
	}

	// approve allowances
	function approve(address _spender, uint256 _value) public   returns (bool) {
		emit Approval(msg.sender, _spender, _value);
		accounts[msg.sender].allowanceOf[_spender] += _value;

		return true;
	}

	// available allowance
	function allowance(address _owner, address _spender) public view returns (uint256) {
		return accounts[_owner].allowanceOf[_spender];
	}

	// no default function, simple contract only, entry-level users
	function() external {
		revert();
	}
}

// Manages BasicCoin instances, including the deployment & registration
contract BasicCoinManager is Owned {
	// a structure wrapping a deployed BasicCoin
	struct Coin {
		address coin;
		address owner;
		address tokenreg;
	}

	// a new BasicCoin has been deployed
	event Created(address indexed owner, address indexed tokenreg, address indexed coin);

	// a list of all the deployed BasicCoins
	Coin[] coins;

	// all BasicCoins for a specific owner
	mapping (address => uint[]) ownedCoins;

	// the base, tokens denoted in micros (matches up with BasicCoin interface above)
	uint constant public base = 1000000;

	// return the number of deployed
	function count() public view returns (uint) {
		return coins.length;
	}

	// get a specific deployment
	function get(uint _index) public view returns (address coin, address owner, address tokenreg) {
		Coin memory c = coins[_index];

		coin = c.coin;
		owner = c.owner;
		tokenreg = c.tokenreg;
	}

	// returns the number of coins for a specific owner
	function countByOwner(address _owner) public view returns (uint) {
		return ownedCoins[_owner].length;
	}

	// returns a specific index by owner
	function getByOwner(address _owner, uint _index) public view returns (address coin, address owner, address tokenreg) {
		return get(ownedCoins[_owner][_index]);
	}

	// deploy a new BasicCoin on the blockchain
	function deploy(uint _totalSupply, string memory _tla, string memory _name, address _tokenreg) public payable returns (bool) {
		TokenReg tokenreg = TokenReg(_tokenreg);
		BasicCoin coin = new BasicCoin(_totalSupply, msg.sender);

		uint ownerCount = countByOwner(msg.sender);
		uint fee = tokenreg.fee();

		ownedCoins[msg.sender].length = ownerCount + 1;
		ownedCoins[msg.sender][ownerCount] = coins.length;
		coins.push(Coin(address(coin), msg.sender, address(tokenreg)));
		tokenreg.registerAs.value(fee)(address(coin), _tla, base, _name, msg.sender);

		emit Created(msg.sender, address(tokenreg), address(coin));

		return true;
	}

	// owner can withdraw all collected funds
	function drain() public only_owner {
		if (!msg.sender.send(address(this).balance)) {
			revert();
		}
	}
}
