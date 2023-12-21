pragma solidity 0.6.12;

import "./libraries/TransferHelper.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract TosDisERC20 {
    using SafeMath for uint;

    bytes32 public constant TokenSignature = "TOSDIS_TRANSIT";

    address public platform;
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Mint(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, address indexed to, uint256 value);

    constructor() public 
    {
        platform = msg.sender;
    }
    
    function initialize(string memory _name, string memory _symbol, uint8 _decimals) public {
        require(msg.sender == platform, "FORBIDDEN");
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function _transfer(address from, address to, uint value) private {
        require(balanceOf[from] >= value, 'ERC20Token: INSUFFICIENT_BALANCE');
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        if (to == address(0)) { // burn
            totalSupply = totalSupply.sub(value);
        }
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        require(allowance[from][msg.sender] >= value, 'ERC20Token: INSUFFICIENT_ALLOWANCE');
        allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }
    
    function mint(address to, uint256 value) external {
        require(msg.sender == platform, "FORBIDDEN");
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Mint(address(0), to, value);
    }

    function burn(address from, uint256 value) external {
        require(msg.sender == platform, "FORBIDDEN");
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Burn(from, address(0), value);
    }
}