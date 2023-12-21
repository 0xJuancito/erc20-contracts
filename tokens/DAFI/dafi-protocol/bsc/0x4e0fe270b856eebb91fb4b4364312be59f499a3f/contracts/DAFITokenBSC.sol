

pragma solidity 0.8.9;
import "./standardtoken.sol";
import "./ownable.sol";




contract DAFITokenBSC is StandardToken, Ownable {
    string public constant _name = "DAFI Token";
    string public constant _symbol = "DAFI";
    uint256 public constant _decimals = 18;

    uint256 public immutable maxSupply;


    constructor(address _owner, address _bridge)  Ownable(_owner,_bridge) {
        maxSupply = 2250000000 * 10**_decimals;
    }


    function mint(uint256 _value, address _beneficiary) external onlyBridge {
        require(_beneficiary != address(0),"Beneficiary cannot be ZERO ADDRESS");
        require(_value > 0,"value should be more than 0");
        require((_value + _totalSupply) <= maxSupply, "Minting amount exceeding max limit");
        balances[_beneficiary] = balances[_beneficiary] + _value;
        unchecked {
            _totalSupply = _totalSupply + _value;
            
        }
        

        emit Transfer(address(0), _beneficiary, _value);
    }

    function burnFrom(uint256 _value, address _beneficiary) external onlyBridge {
        require(_beneficiary != address(0),"Beneficiary cannot be ZERO ADDRESS");
        require(balanceOf(_beneficiary) >= _value, "User does not have sufficient tokens to burn");
        require(_value <= allowed[_beneficiary][msg.sender], "user did not approve the bridge to burn the said amount.");

        _totalSupply = _totalSupply - _value;
        balances[_beneficiary] = balances[_beneficiary] - _value;
        allowed[_beneficiary][msg.sender] = allowed[_beneficiary][msg.sender] - _value;

        emit Transfer(_beneficiary, address(0), _value);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public pure returns (uint256) {
        return _decimals;
    }
}
