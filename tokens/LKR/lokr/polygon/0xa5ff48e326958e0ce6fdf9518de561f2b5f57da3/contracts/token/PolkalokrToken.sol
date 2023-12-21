pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";


contract PolkalokrToken is ERC20Upgradeable, PausableUpgradeable, AccessControlUpgradeable {

    string constant NAME    = 'Polkalokr';
    string constant SYMBOL  = 'LKR';
    uint8 constant DECIMALS  = 18;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE"); //Pauser can pause/unpause
    bytes32 public constant WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE"); //Whitelisted addresses can transfer token when paused
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE"); //Blacklisted addresses can not transfer token and their tokens can't be transferred by others
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); //Minter Addresses are the only ones allowed to mint
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE"); //Burner Addresses are the only ones allowed to burn

    modifier onlyAdmin(){
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "!admin");
        _;
    }

    modifier onlyPauser(){
        require(hasRole(PAUSER_ROLE, _msgSender()), "!pauser");
        _;
    }

    function initialize(address minterNburnerAddress) external initializer {
        __PolkalokrToken_init();
        _setupRole(MINTER_ROLE, minterNburnerAddress);
        _setupRole(BURNER_ROLE, minterNburnerAddress);
    }

    function __PolkalokrToken_init() internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(NAME, SYMBOL);
        __Pausable_init_unchained();
        __AccessControl_init_unchained();
        __PolkalokrToken_init_unchained();
    }

    function __PolkalokrToken_init_unchained() internal initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());   // DEFAULT_ADMIN_ROLE can grant other roles
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(WHITELISTED_ROLE, _msgSender());


    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused() || hasRole(WHITELISTED_ROLE, _msgSender()), "transfers paused");
        require(!hasRole(BLACKLISTED_ROLE, _msgSender()), "sender blacklisted");
        require(!hasRole(BLACKLISTED_ROLE, from), "from blacklisted");
       
    }

    function mint(address _to, uint256 _amount) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "minting forbidden");

        _mint(_to, _amount);
      
    }

    function burnFrom(address _from, uint256 _amount) external {
        uint256 currentAllowance = allowance(_from,_msgSender());
        require(currentAllowance >= _amount || _from == _msgSender(), "ERC20: burn amount exceeds allowance");
        require(hasRole(BURNER_ROLE, _msgSender()), "burn forbidden");
        _burn(_from, _amount);
      
    }

    function pause() external onlyPauser {
        _pause();
    }

    function unpause() external onlyPauser {
        _unpause();
    }

}