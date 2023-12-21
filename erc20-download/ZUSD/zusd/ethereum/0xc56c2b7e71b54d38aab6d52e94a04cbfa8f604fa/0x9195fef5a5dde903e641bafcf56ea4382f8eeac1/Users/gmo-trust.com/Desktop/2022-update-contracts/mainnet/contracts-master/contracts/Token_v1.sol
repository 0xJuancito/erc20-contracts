pragma solidity 0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./Roles/Owner.sol";

contract Token_v1 is Initializable, ERC20, Owner {
    string public name;
    string public symbol;
    uint8 public decimals;

    event Mint(address indexed mintee, uint256 amount, address indexed sender);
    event Burn(address indexed burnee, uint256 amount, address indexed sender);

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner,
        address _admin,
        address _capper,
        address _prohibiter,
        address _pauser,
        address _minterAdmin,
        address _minter
        ) public initializer {
            require(_owner != address(0), "_owner is the zero address");
            require(_admin != address(0), "_admin is the zero address");
            require(_capper != address(0), "_capper is the zero address");
            require(_prohibiter != address(0), "_prohibiter is the zero address");
            require(_pauser != address(0), "_pauser is the zero address");
            require(_minterAdmin != address(0), "_minterAdmin is the zero address");
            require(_minter != address(0), "_minter is the zero address");
            name = _name;
            symbol = _symbol;
            decimals = _decimals;
            owner = _owner;
            admin = _admin;
            capper = _capper;
            prohibiter = _prohibiter;
            pauser = _pauser;
            minterAdmin = _minterAdmin;
            minter = _minter;
    }

    function cap(uint256 _amount) public onlyCapper whenNotPaused isNaturalNumber(_amount) {
        require(totalSupply() <= _amount, "this amount is less than the totalySupply");
        _cap(_amount);
    }

    function mint(address _account, uint256 _amount) public onlyMinter whenNotPaused notMoreThanCapacity(totalSupply().add(_amount)) isNaturalNumber(_amount) {
        _mint(_account, _amount);
        emit Mint(_account, _amount, msg.sender);
    }

    function transfer(address _recipient, uint256 _amount) public whenNotPaused onlyNotProhibited(msg.sender) isNaturalNumber(_amount) returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public whenNotPaused onlyNotProhibited(_sender) isNaturalNumber(_amount) returns (bool) {
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function burn(uint256 _amount) public isNaturalNumber(_amount) {
        _burn(msg.sender, _amount);
        emit Burn(msg.sender, _amount, msg.sender);
    }
}