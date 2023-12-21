// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./token/BEP20/BEP20.sol";
import "./interfaces/IBP.sol";

// Elpis Battle Governance token
contract ElpisBattle is BEP20("Elpis Battle", "EBA") {
    // Bot prevent
    IBP public botPrevent;
    // Bot prevent status
    bool public botPreventEnabled;
    // Total supply is 1,000,000,000 tokens
    uint256 private constant _cap = 1e27;

    mapping(address => bool) public minters;

    modifier onlyMinter() {
        require(minters[msg.sender], "EBA::not authorized");
        _;
    }

    modifier preventTransfer(uint256 amount) {
        if (botPreventEnabled) {
            botPrevent.protect(amount);
        }
        _;
    }

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    event BotPreventAdded(IBP indexed botPrevent);
    event BotPreventEnabled(bool indexed enabled);
    event BotPreventTransfer(address sender, address recipient, uint256 amount);

    modifier capNotExceeded(uint256 _amount) {
        require(totalSupply().add(_amount) <= cap(), "EBA::cap exceeded");
        _;
    }

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor() public {}

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public pure virtual returns (uint256) {
        return _cap;
    }

    /// @dev Owner can set bot prevent contract addresses
    /// @param _botPrevent Account address
    function setBotPrevent(IBP _botPrevent) external onlyOwner {
        require(address(botPrevent) == address(0), "BotPrevent only initialize one time");
        botPrevent = _botPrevent;
        emit BotPreventAdded(_botPrevent);
    }

    /// @dev Owner can set status of bot prevent contract
    /// @param _botPreventEnabled Account address
    function setBotPreventEnabled(bool _botPreventEnabled) external onlyOwner {
        require(
            address(botPrevent) != address(0),
            "You have to set BotPrevent address first"
        );
        botPreventEnabled = _botPreventEnabled;
        emit BotPreventEnabled(_botPreventEnabled);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override preventTransfer(amount) {
        super._transfer(sender, recipient, amount);
    }

    /// @dev Add one account to be the minter
    /// @param _account Account address
    function addMinter(address _account) public onlyOwner {
        minters[_account] = true;
        emit MinterAdded(_account);
    }

    /// @dev Revoke minter role of one minter
    /// @param _account minter address
    function revokeMinter(address _account) public onlyOwner {
        minters[_account] = false;
        emit MinterRemoved(_account);
    }

    /// @dev Renounce current minter role
    function renounceMinter() public onlyMinter {
        minters[msg.sender] = false;
        emit MinterRemoved(msg.sender);
    }

    function mint(uint256 _amount)
        public
        override
        onlyMinter
        capNotExceeded(_amount)
        returns (bool)
    {
        _mint(_msgSender(), _amount);
        return true;
    }

    function mint(address _to, uint256 _amount)
        public
        onlyMinter
        capNotExceeded(_amount)
        returns (bool)
    {
        _mint(_to, _amount);
        return true;
    }
}
