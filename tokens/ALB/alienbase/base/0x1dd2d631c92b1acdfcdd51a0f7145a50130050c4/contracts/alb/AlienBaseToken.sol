// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract AlienBaseToken is ERC20, ERC20Permit, AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant TAKE_FEE_ROLE = keccak256("TAKE_FEE_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");

    uint256 private _maxSupply = 510000000 * 10**decimals(); // 510 million tokens is maximum supply
    uint256 private _initialSupply = 26010000 * 10**decimals(); // 5.1% of 510,000,000 tokens is the initial supply

    uint256 public changeMinter;
    uint256 public constant MINT_DELAY = 7 days;

    address private _trustedForwarder;
    bool private initialized;

    // Control support for EIP-2771 Meta Transactions
    bool public metaTxnsEnabled = false;

    event TokensRescued(address indexed sender, address indexed token, uint256 value);
    event MetaTxnsEnabled(address indexed caller);
    event MetaTxnsDisabled(address indexed caller);
    event MinterChange(uint timestamp, uint executionStart);

    constructor(address trustedForwarder) ERC20("AlienBase Token", "ALB") ERC20Permit("AlienBase Token") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(RESCUER_ROLE, _msgSender());

        _trustedForwarder = trustedForwarder;

        //mint initial supply in constructor, rest in contract
        _mint(_msgSender(), _initialSupply);
    }

    //single use function to set up Distributor as minter
    function initialize(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!initialized, "AI");
        _setupRole(MINTER_ROLE, minter);
        initialized = true;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function _msgSender() internal view override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    /**
     * @dev Returns the maximum amount of tokens that can be minted.
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= _maxSupply, "ERC20: cannot mint more tokens, cap exceeded");
        _mint(to, amount);
    }

    //Function to start minter change timelock
    //Minting is done by contract, but we might want to change minting rules later
    //Since this is a touchy subject, best to add timelock
    
    function setUpMinter() external onlyRole(DEFAULT_ADMIN_ROLE) {
        //no checks, allows refreshing timer
        changeMinter = block.timestamp;
        emit MinterChange(changeMinter, changeMinter + MINT_DELAY);
    }

    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        if(role == MINTER_ROLE) {
            require(changeMinter != 0 && block.timestamp >= changeMinter + MINT_DELAY, "MTE");
            require(block.timestamp <= changeMinter + (MINT_DELAY * 2), "EXP");
            changeMinter = 0; //reset
        }
        super.grantRole(role, account);
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function rescueTokens(IERC20 token, uint256 value) external onlyRole(RESCUER_ROLE) {
        token.transfer(_msgSender(), value);

        emit TokensRescued(_msgSender(), address(token), value);
    }

    // Enable support for meta transactions
    function enableMetaTxns() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!metaTxnsEnabled, "Meta transactions are already enabled");

        metaTxnsEnabled = true;
        emit MetaTxnsEnabled(_msgSender());
    }

    // Disable support for meta transactions
    function disableMetaTxns() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(metaTxnsEnabled, "Meta transactions are already disabled");

        metaTxnsEnabled = false;
        emit MetaTxnsDisabled(_msgSender());
    }
}
