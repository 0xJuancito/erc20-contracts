// SPDX-License-Identifier: MIT
pragma solidity >= 0.6.12;

import "./libs/ProtofiERC20.sol";

/**
This is the contract of the primary token.

Features:
- Ownable
- Strictly related to the second token
- You can use the second token to claim the primary token.
- Antiwhale,  can be set up only by operator

Owner --> Masterchef for farming features
Operator --> Team address that handles the antiwhales settings when needed
*/
contract ProtonToken is ProtofiERC20 {

    // Address to the secondary token
    address public electron;
    bool private _isElectronSetup = false;

    // Addresses that excluded from antiWhale
    mapping(address => bool) private _excludedFromAntiWhale;

    // Max transfer amount rate in basis points. Eg: 50 - 0.5% of total supply (default the anti whale feature is turned off - set to 10000.)
    uint16 public maxTransferAmountRate = 10000;
    // Minimum transfer amount rate in basis points. Deserved for user trust, we can't block users to send this token.
    // maxTransferAmountRate cannot be lower than BASE_MIN_TRANSFER_AMOUNT_RATE
    uint16 public constant BASE_MAX_TRANSFER_AMOUNT_RATE = 100; // Cannot be changed, ever!
    // The operator can only update the Anti Whale Settings
    address private _operator;

    // Events
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event MaxTransferAmountRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);

    constructor() public ProtofiERC20("Protofi Token", "PROTO"){

        // After initializing the token with the original constructor of ProtofiERC20
        // setup antiwhale variables.
        _operator = msg.sender;
        emit OperatorTransferred(address(0), _operator);

        _excludedFromAntiWhale[msg.sender] = true; // Original deployer address
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true;
        _excludedFromAntiWhale[BURN_ADDRESS] = true;
    }

    /**
    @dev similar to onlyOwner but used to handle the antiwhale side of the smart contract.
    In that way the ownership can be transferred to the MasterChef without preventing devs to modify
    antiwhale settings.
     */
    modifier onlyOperator() {
        require(_operator == msg.sender, "operator: caller is not the operator");
        _;
    }

    /**
    Exludes sender to send more than a certain amount of tokens given settings, if the
    sender is not whitelisted!
     */
    modifier antiWhale(address sender, address recipient, uint256 amount) {
        if (maxTransferAmount() > 0) {
            if (
                _excludedFromAntiWhale[sender] == false
            ) {
                require(amount <= maxTransferAmount(), "PROTO::antiWhale: Transfer amount exceeds the maxTransferAmount");
            }
        }
        _;
    }

    /**
     * @dev Returns the max transfer amount.
     */
    function maxTransferAmount() public view returns (uint256) {
        return totalSupply().mul(maxTransferAmountRate).div(10000);
    }

    /**
     * @dev Update the max transfer amount rate.
     * Can only be called by the current operator.
     */
    function updateMaxTransferAmountRate(uint16 _maxTransferAmountRate) public onlyOperator {
        require(_maxTransferAmountRate <= 10000, "PROTO::updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate.");
        require(_maxTransferAmountRate >= BASE_MAX_TRANSFER_AMOUNT_RATE, "PROTO::updateMaxTransferAmountRate: _maxTransferAmountRate should be at least _maxTransferAmountRate");
        emit MaxTransferAmountRateUpdated(msg.sender, maxTransferAmountRate, _maxTransferAmountRate);
        maxTransferAmountRate = _maxTransferAmountRate;
    }

    /**
     * @dev Returns the address is excluded from antiWhale or not.
     */
    function isExcludedFromAntiWhale(address _account) public view returns (bool) {
        return _excludedFromAntiWhale[_account];
    }

    /**
     * @dev Exclude or include an address from antiWhale.
     * Can only be called by the current operator.
     */
    function setExcludedFromAntiWhale(address _account, bool _excluded) public onlyOperator {
        _excludedFromAntiWhale[_account] = _excluded;
    }

    /// @dev Throws if called by any account other than the owner or the secondary token
    modifier onlyOwnerOrElectron() {
        require(isOwner() || isElectron(), "caller is not the owner or electron");
        _;
    }

    /// @dev Returns true if the caller is the current owner.
    function isOwner() public view returns (bool) {
        return msg.sender == owner();
    }

    /// @dev Returns true if the caller is electron contracts.
    function isElectron() internal view returns (bool) {
        return msg.sender == address(electron);
    }

    /// @dev Sets the secondary token address.
    function setupElectron(address _electron) external onlyOwner{
        require(!_isElectronSetup, "The Electron token address has already been set up. No one can change it anymore.");
        electron = _electron;
        _isElectronSetup = true;
    }

    /**
    @notice Creates `_amount` token to `_to`. Must only be called by the masterchef or
    by the secondary token(during swap)
    */
    function mint(address _to, uint256 _amount) external virtual override onlyOwnerOrElectron  {
        _mint(_to, _amount);
    }

    /// @dev overrides transfer function to meet tokenomics of PROTO
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override antiWhale(sender, recipient, amount) {
        require(amount > 0, "amount 0");

        if (recipient == BURN_ADDRESS) {
            // Burn all the amount
            super._burn(sender, amount);
        } else {
            // Transfer all the amount
            super._transfer(sender, recipient, amount);
        }
    }

    /**
     * @dev Transfers operator of the contract to a new account (`newOperator`).
     * Can only be called by the current operator.
     */
    function transferOperator(address newOperator) public onlyOperator {
        require(newOperator != address(0), "ProtonToken::transferOperator: new operator is the zero address");
        emit OperatorTransferred(_operator, newOperator);
        _operator = newOperator;
    }
}