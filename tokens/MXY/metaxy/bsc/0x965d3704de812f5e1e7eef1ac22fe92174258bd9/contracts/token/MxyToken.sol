// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MxyToken is Ownable, ERC20Burnable {
    using SafeERC20 for IERC20;

    uint256 public constant MINIMUM_THRESHOLD_WHALE = 1e5 ether;
    uint256 public constant MAXIMUM_TOTAL_SUPPLY = 1.5e9 ether;

    mapping(address => bool) public whales;

    bool public antiWhaleEnabled;
    uint256 public antiWhaleTime;
    uint256 public antiWhaleAmount;

    constructor(address _ownerAddress, uint256 _totalSupply)
        Ownable()
        ERC20("MXY Token", "MXY")
    {
        require(
            _totalSupply <= MAXIMUM_TOTAL_SUPPLY,
            "MXY::mint: exceeding the permitted limits"
        );
        _mint(_ownerAddress, _totalSupply);
        transferOwnership(_ownerAddress);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function mint(uint256 _amount) public onlyOwner returns (bool) {
        uint256 totalSupply = totalSupply();
        require(
            totalSupply + _amount <= MAXIMUM_TOTAL_SUPPLY,
            "MXY::mint: exceeding the permitted limits"
        );
        _mint(_msgSender(), _amount);
        return true;
    }

    /**
     * @notice set a whale's address
     *
     * @param _account address
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function setWhale(address _account) external onlyOwner {
        require(!whales[_account], "MXY: account was set");
        whales[_account] = true;
    }

    /**
     * @notice remove a whale's address
     *
     * @param _account address
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function removeWhale(address _account) external onlyOwner {
        require(whales[_account], "MXY: account was not set");
        delete whales[_account];
    }

    /**
     * @notice enable anti whale
     *
     * @param _amount amount
     * @param _duration duration
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function enableAntiWhale(uint256 _amount, uint256 _duration)
        external
        onlyOwner
    {
        require(!antiWhaleEnabled, "MXY: anti whale was enabled");
        require(_amount > MINIMUM_THRESHOLD_WHALE, "MXY: amount is invalid");

        antiWhaleEnabled = true;
        antiWhaleAmount = _amount;
        antiWhaleTime = block.timestamp + _duration;
    }

    /**
     * @notice disable anti whale
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function disableAntiWhale() external onlyOwner {
        antiWhaleEnabled = false;
        antiWhaleAmount = 0;
        antiWhaleTime = 0;
    }

    /**
     * @notice emergency withdraw token
     *
     * @param _token token address
     * @param _to to address
     * @param _amount amount
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function emergencyWithdraw(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(address(0) != _to, "MXY: transfer to the zero address");
        if (_token == IERC20(address(0))) {
            (bool success, ) = _to.call{value: _amount}("");
            require(success, "MXY: Transfer failed");
        } else {
            _token.safeTransfer(_to, _amount);
        }
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal virtual override {
        if (antiWhaleEnabled) {
            if (
                antiWhaleTime > block.timestamp &&
                _amount > antiWhaleAmount &&
                whales[_sender]
            ) {
                revert("MXY: Anti Whale");
            }
        }

        super._transfer(_sender, _recipient, _amount);
    }
}
