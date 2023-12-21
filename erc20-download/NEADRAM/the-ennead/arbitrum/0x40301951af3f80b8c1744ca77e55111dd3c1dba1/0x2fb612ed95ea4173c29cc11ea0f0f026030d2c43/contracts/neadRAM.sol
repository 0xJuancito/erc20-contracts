// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./interfaces/Ramses/IVotingEscrow.sol";
import "./interfaces/Ramses/IRewardsDistributor.sol";
import "./interfaces/INeadStake.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract VeDepositor is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Ramses contracts
    IERC20Upgradeable public token;
    IVotingEscrow public votingEscrow;
    IRewardsDistributor public veDistributor;

    // Ennead contracts
    address public lpDepositor;
    address public neadStake;
    uint256 public tokenID;
    uint256 public unlockTime;

    uint256 public constant WEEK = 1 weeks;
    uint256 public constant MAX_LOCK_TIME = 4 * 365 * 86400;

    uint256 public percentToBribes;
    bool public isBribeEnabled;
    address public bribeReceiver;

    uint256 public depositFee;
    event ClaimedFromVeDistributor(address indexed user, uint256 amount);
    event Merged(address indexed user, uint256 tokenID, uint256 amount);
    event UnlockTimeUpdated(uint256 unlockTime);
    event FeeUpdated(uint256 fee);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20Upgradeable _token,
        IVotingEscrow _votingEscrow,
        IRewardsDistributor _veDist,
        address admin,
        address pauser,
        address setter
    ) public initializer {
        __Pausable_init();
        __AccessControlEnumerable_init();
        __ERC20_init("neadRAM: Tokenized veRAM", "neadRAM");

        token = _token;
        votingEscrow = _votingEscrow;
        veDistributor = _veDist;

        // approve vesting escrow to transfer RAM (for adding to lock)
        _token.approve(address(_votingEscrow), type(uint256).max);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UNPAUSER_ROLE, admin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(SETTER_ROLE, setter);
    }

    function setAddresses(
        address _lpDepositor,
        address _neadStake
    ) external onlyRole(SETTER_ROLE) {
        lpDepositor = _lpDepositor;
        neadStake = _neadStake;
        _approve(address(this), _neadStake, type(uint).max);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    function onERC721Received(
        address _operator,
        address,
        uint256 _tokenID,
        bytes calldata
    ) external whenNotPaused returns (bytes4) {
        require(
            msg.sender == address(votingEscrow),
            "Can only receive veRAM NFTs"
        );

        require(_tokenID > 0, "Cannot receive zero tokenID");

        (uint256 amount, uint256 end) = votingEscrow.locked(_tokenID);

        if (tokenID == 0) {
            tokenID = _tokenID;
            unlockTime = end;
            votingEscrow.safeTransferFrom(address(this), lpDepositor, _tokenID);
        } else {
            votingEscrow.merge(_tokenID, tokenID);
            if (end > unlockTime) unlockTime = end;
            emit Merged(_operator, _tokenID, amount);
        }

        if (depositFee > 0) {
            uint cut = (amount * depositFee) / 100;
            _mint(bribeReceiver, cut);
            _mint(_operator, amount - cut);
        } else {
            _mint(_operator, amount);
        }

        extendLockTime();

        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    /**
        @notice Merge a veRAM NFT previously sent to this contract
                with the main ennead NFT
        @dev This is primarily meant to allow claiming balances from NFTs
             incorrectly sent using `transferFrom`. To deposit an NFT
             you should always use `safeTransferFrom`.
        @param _tokenID ID of the NFT to merge
        @return bool success
     */
    function merge(uint256 _tokenID) external onlyRole(OPERATOR_ROLE) whenNotPaused returns (bool) {
        require(tokenID != _tokenID, "ENNEAD TOKEN ID");
        (uint256 amount, uint256 end) = votingEscrow.locked(_tokenID);
        require(amount > 0, "ZERO Amount");

        votingEscrow.merge(_tokenID, tokenID);
        if (end > unlockTime) unlockTime = end;
        emit Merged(msg.sender, _tokenID, amount);

        _mint(msg.sender, amount);
        extendLockTime();

        return true;
    }

    /**
        @notice Deposit RAM tokens and mint neadRAM
        @param _amount Amount of RAM to deposit
        @return bool success
     */
    function depositTokens(
        uint256 _amount
    ) external whenNotPaused returns (bool) {
        require(tokenID != 0, "First deposit must be NFT");

        token.safeTransferFrom(msg.sender, address(this), _amount);
        votingEscrow.increase_amount(tokenID, _amount);
        _mint(msg.sender, _amount);
        extendLockTime();

        return true;
    }

    /**
        @notice Extend the lock time of the protocol's veRAM NFT
        @dev Lock times are also extended each time new neadRAM is minted.
             If the lock time is already at the maximum duration, calling
             this function does nothing.
     */
    function extendLockTime() public {
        uint256 maxUnlock = ((block.timestamp + MAX_LOCK_TIME) / WEEK) * WEEK;
        if (maxUnlock > unlockTime) {
            votingEscrow.increase_unlock_time(tokenID, MAX_LOCK_TIME);
            unlockTime = maxUnlock;
            emit UnlockTimeUpdated(unlockTime);
        }
    }

    function claimRebase() external whenNotPaused returns (bool) {
        veDistributor.claim(tokenID);
        (uint256 amount, ) = votingEscrow.locked(tokenID);
        amount -= totalSupply();
        if (amount > 0) {
            if (isBribeEnabled) {
                uint amountToBribes = (amount * percentToBribes) / 1e18;
                amount -= amountToBribes;
                _mint(address(this), amount);
                _mint(bribeReceiver, amountToBribes);
                INeadStake(neadStake).notifyRewardAmount(address(this), amount);
            } else {
                _mint(address(this), amount);
                INeadStake(neadStake).notifyRewardAmount(address(this), amount);
            }
        }
        return true;
    }

    function burn(uint amount) public override {
        return;
    }

    function burnFrom(address account, uint amount) public override {
        return;
    }

    function setBribeReceiver(
        address _bribeReceiver
    ) external onlyRole(SETTER_ROLE) {
        bribeReceiver = _bribeReceiver;
    }

    /// @notice must be percent * 1e18
    function setBribePercent(
        uint _percentToBribes
    ) external onlyRole(SETTER_ROLE) {
        percentToBribes = _percentToBribes;
    }

    /// @notice set veNFT deposit fee
    function setDepositFee(uint rate) external onlyRole(SETTER_ROLE) {
        depositFee = rate;
        emit FeeUpdated(rate);
    }

    function enableRebaseToBribe(bool enabled) external onlyRole(SETTER_ROLE) {
        isBribeEnabled = enabled;
    }
}
