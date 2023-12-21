// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../openzeppelin/ERC20.sol";
import "../openzeppelin/SafeMath.sol";
import "../openzeppelin/Pausable.sol";

contract GRBE_V2 is ERC20, Pausable {
    using SafeMath for uint256;

    address private governance;
    address private pendingGovernance;
    mapping(address => bool) private minters;

    uint256 public constant cap = 1000000000 ether;

    uint256 public antiWhaleThreshold;
    bool public isAntiWhale;

    mapping(address => bool) public _isExcludedPause;
    mapping(address => bool) public _isExcludedFromAntiWhale;
    mapping(address => bool) public _isIncludedToAntiWhale;

    constructor() Pausable() ERC20("Green_Beli_v2", "GRBE") {
        governance = msg.sender;

        isAntiWhale = true;

        antiWhaleThreshold = cap.div(100); // 1% cap

        _isExcludedFromAntiWhale[msg.sender] = true;
        _isExcludedPause[msg.sender] = true;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "GRBE_V2: !governance");
        _;
    }

    function setGovernance(address governance_) external virtual onlyGovernance {
        pendingGovernance = governance_;
    }

    function claimGovernance() external virtual {
        require(msg.sender == pendingGovernance, "GRBE_V2: !pendingGovernance");
        governance = pendingGovernance;
        delete pendingGovernance;
    }

    function addMinter(address minter_) external virtual onlyGovernance {
        require(minter_ != address(0), "GRBE_V2: zero address");
        minters[minter_] = true;
    }

    function removeMinter(address minter_) external virtual onlyGovernance {
        require(minter_ != address(0), "GRBE_V2: zero address");
        minters[minter_] = false;
    }

    /**
     * @dev Pauses all token transfers. See {Pausable-_pause}.
     *
     * Requirements:
     * - the caller must be the governance.
     */
    function pause() external virtual onlyGovernance {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers. See {Pausable-_unpause}.
     *
     * Requirements:
     * - the caller must be the governance.
     */
    function unpause() external virtual onlyGovernance {
        _unpause();
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     * - minted tokens must not cause the total supply to go over the cap.
     */
    function _beforeTokenTransfer(
        address from_,
        address to_,
        uint256 amount_
    ) internal virtual override {
        super._beforeTokenTransfer(from_, to_, amount_);

        if (!_isExcludedPause[from_] && !_isExcludedPause[to_]) {
            require(!paused(), "GRBE_V2: token transfer while paused");
        }

        if (isAntiWhale && !_isExcludedFromAntiWhale[from_]) {
            if (_isIncludedToAntiWhale[to_]) {
                require(amount_ <= antiWhaleThreshold, "Anti whale: can't buy more than the specified threshold");
                require(balanceOf(from_).add(amount_) <= antiWhaleThreshold, "Anti whale: can't hold more than the specified threshold");
            }
        }

        if (from_ == address(0)) {
            // When minting tokens
            require(totalSupply().add(amount_) <= cap, "GRBE_V2: cap exceeded");
        }
    }

    /**
     * @dev Creates `amount` new tokens for `to`. See {ERC20-_mint}.
     *
     * Requirements:
     * - the caller must have the governance or minter.
     */
    function mint(address to_, uint256 amount_) external virtual {
        require(msg.sender == governance || minters[msg.sender], "GRBE_V2: !governance && !minter");
        _mint(to_, amount_);
    }

    /**
     * @dev Destroys `amount` tokens from the caller. See {ERC20-_burn}.
     */
    function burn(uint256 amount_) external virtual {
        _burn(msg.sender, amount_);
    }

    function setAntiWhale(bool _isAntiWhale) external onlyGovernance {
        isAntiWhale = _isAntiWhale;
    }

    function setIsExcludedPause(address _account, bool _status) external onlyGovernance {
        require(_account != address(0), "GRBE_V2: zero address");
        _isExcludedPause[_account] = _status;
    }

    function setExcludedAntiWhale(address _account, bool _status) external onlyGovernance {
        require(_account != address(0), "GRBE_V2: zero address");
        _isExcludedFromAntiWhale[_account] = _status;
    }

    function setIncludedToAntiWhale(address _account, bool _status) external onlyGovernance {
        require(_account != address(0), "GRBE_V2: zero address");
        _isIncludedToAntiWhale[_account] = _status;
    }

    function setAntiWhaleThreshold(uint256 _antiWhaleThreshold) external onlyGovernance {
        antiWhaleThreshold = _antiWhaleThreshold;
    }
}
