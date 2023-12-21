
pragma solidity 0.8.9;
import "./erc20basic.sol";
 contract BasicToken is ERC20Basic {

    mapping(address => uint256) internal balances;

    uint256 internal _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev transfer token for a specified address
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transfer(address _to, uint256 _value) public override returns (bool) {
        require(_to != address(0),"Cannot call transfer with to as ZERO ADDRESS");
        require(_value <= balances[msg.sender],"cannot transfer amount more than your balance");
        unchecked {
            balances[msg.sender] = balances[msg.sender] - _value;
            
        }
        
        balances[_to] = balances[_to] + _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return balance An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address _owner) public override view returns (uint256 balance) {
        return balances[_owner];
    }
}