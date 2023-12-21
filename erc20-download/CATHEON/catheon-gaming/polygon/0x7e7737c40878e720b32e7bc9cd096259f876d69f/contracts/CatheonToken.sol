// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// Catheon token
/// @dev The ownable, upgradeable ERC20 contract
/// @notice Do not override Ownable functions to checking ownership (Ownership can not be renounced)
contract CatheonToken is ERC20, Ownable {
    // addresses applying fee (address => isApplyingFee)
    mapping(address => bool) public feeApplies;
    // max total supply limit 10_000_000_000 * DECIMAL
    uint256 public maxSupply;
    // treasury address
    address private _treasury;
    // token-transfer fee percentage
    uint256 private _feePercent;
    // fee percentage division
    uint256 private constant PERCENTAGE_DIVISION = 1000;
    // 0%
    uint256 private constant PERCENTAGE_ZERO = 0;
    // max fee percentage (10%)
    uint256 private constant MAX_FEE_PERCENTAGE = 100;

    /// @dev Emitted when owner change treasury address
    event SetTreasury(address indexed treasury);
    /// @dev Emitted when owner set whether the address is applying fee or not
    event SetFeeApplyingAddress(address indexed target, bool isApplying);
    /// @dev Emitted when owner change fee percentage
    event SetFeePercent(uint256 indexed percentage);
    /// @dev Emitted when owner set max-supply
    event SetMaxSupply(uint256 indexed supply);

    /// @dev Constructor
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param initialBalance_ Initial token balance of deployer
    /// @param treasury_ Treasury address receiving fee
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialBalance_,
        address treasury_
    ) ERC20(name_, symbol_) {
        require(bytes(name_).length > 0, "Empty Name");
        require(bytes(symbol_).length > 2, "Invalid symbol: min 3 letters");
        require(
            initialBalance_ <= 1e19 && initialBalance_ > 0,
            "Invalid initial balance"
        );
        require(treasury_ != address(0), "Zero Treasury Address");

        _treasury = treasury_;

        /// default max supply 10_000_000_000 * (10 ** decimals)
        maxSupply = 1e19;
        /// default fee percentage (5%)
        _feePercent = 50;

        _mint(msg.sender, initialBalance_);
    }

    /// @dev Mint token by owner at any time
    /// @param account Target address
    /// @param amount Mint amount
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    /// @dev Return the number of decimals
    /// @return Token decimals
    function decimals() public pure override returns (uint8) {
        return 9;
    }

    /// @dev Internal transfer token
    /// @param sender From address
    /// @param recipient To address
    /// @param amount Token amount
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        uint256 receiveAmount = amount;
        address treasuryAddress = _treasury;

        if (
            sender != treasuryAddress &&
            recipient != treasuryAddress &&
            (feeApplies[sender] == true || feeApplies[recipient] == true)
        ) {
            // fee avoidance
            require(amount >= PERCENTAGE_DIVISION, "Too small transfer");

            uint256 feeAmount = (amount * _feePercent) / PERCENTAGE_DIVISION;
            receiveAmount = amount - feeAmount;

            // feeAmount can not be zero in here
            ERC20._transfer(sender, treasuryAddress, feeAmount);
        }

        ERC20._transfer(sender, recipient, receiveAmount);
    }

    /// @dev Set new treasury address by owner
    /// @param to Target address
    function setTreasury(address to) external onlyOwner {
        require(
            to != address(0) && to != _treasury,
            "Invalid Treasury Address"
        );

        _treasury = to;

        emit SetTreasury(to);
    }

    /// @dev Set whether the address is applying fee or not
    /// @param applyingAddr Target address
    /// @param isApplying Flag (true: apply fee, false: don't apply fee)
    function setFeeApplyingAddr(address applyingAddr, bool isApplying)
        external
        onlyOwner
    {
        require(feeApplies[applyingAddr] != isApplying, "Already Set");

        feeApplies[applyingAddr] = isApplying;

        emit SetFeeApplyingAddress(applyingAddr, isApplying);
    }

    /// @dev Set fee percentage by owner
    /// @param percentage Fee percentage
    function setFee(uint256 percentage) external onlyOwner {
        require(
            percentage != PERCENTAGE_ZERO && percentage <= MAX_FEE_PERCENTAGE,
            "Invalid Fee Percentage"
        );
        require(_feePercent != percentage, "Same Fee Percentage");

        _feePercent = percentage;

        emit SetFeePercent(percentage);
    }

    /// @dev Get current fee percentage
    /// @return Fee percentage
    function fee() external view returns (uint256) {
        return _feePercent;
    }

    /// @dev Get current treasury address
    /// @return Treasury address
    function treasury() external view returns (address) {
        return _treasury;
    }

    /// @dev Override ERC20`s _mint function for adding max_total_supply limit validation
    /// @param account The target address minting tokens
    /// @param amount The minting token amount
    function _mint(address account, uint256 amount) internal override {
        uint256 _totalSupply = totalSupply();
        require(_totalSupply + amount <= maxSupply, "Limited By Max Supply");

        // call ERC20 _mint function
        ERC20._mint(account, amount);
    }

    /// @dev Set new max supply by owner
    /// @param supply The new max supply amount
    function setMaxSupply(uint256 supply) external onlyOwner {
        require(totalSupply() <= supply, "Invalid Max Supply");

        maxSupply = supply;

        emit SetMaxSupply(supply);
    }

    /// @dev Burn token by owner at any time
    /// @param amount Burning token amount
    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }
}
