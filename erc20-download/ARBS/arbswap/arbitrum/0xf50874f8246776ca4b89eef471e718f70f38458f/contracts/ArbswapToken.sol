// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ArbswapToken is ERC20, Ownable {
    address public LiquidityMining;
    address public Staking;
    address public Community;
    address public Partnership;
    address public InitialLiquidity;
    address public Team;

    uint256 public constant MaxTotalSupply = 1e9 ether;
    uint256 public constant LiquidityMiningMaxSupply = 3e8 ether;
    uint256 public constant StakingMaxSupply = 5e7 ether;
    uint256 public constant CommunityMaxSupply = 25e7 ether;
    uint256 public constant PartnershipMaxSupply = 1e8 ether;
    uint256 public constant InitialLiquidityMaxSupply = 1e8 ether;
    uint256 public constant TeamMaxSupply = 2e8 ether;

    uint256 public liquidityMiningTotalSupply;
    uint256 public stakingTotalSupply;
    uint256 public communityTotalSupply;
    uint256 public partnershipTotalSupply;
    uint256 public initialLiquidityTotalSupply;
    uint256 public teamTotalSupply;

    event NewLiquidityMining(address indexed liquidityMining);
    event NewStaking(address indexed staking);
    event NewCommunity(address indexed community);
    event NewPartnership(address indexed partnership);
    event NewInitialLiquidity(address indexed initialLiquidity);
    event NewTeam(address indexed team);

    modifier onlyLiquidityMining() {
        require(msg.sender == LiquidityMining, "Not LiquidityMining");
        _;
    }

    modifier onlyStaking() {
        require(msg.sender == Staking, "Not Staking");
        _;
    }

    modifier onlyCommunity() {
        require(msg.sender == Community, "Not Community");
        _;
    }

    modifier onlyPartnership() {
        require(msg.sender == Partnership, "Not Partnership");
        _;
    }

    modifier onlyInitialLiquidity() {
        require(msg.sender == InitialLiquidity, "Not InitialLiquidity");
        _;
    }

    modifier onlyTeam() {
        require(msg.sender == Team, "Not Team");
        _;
    }

    constructor() ERC20("Arbswap Token", "ARBS") {}

    /**
     * @notice Mint by LiquidityMining
     * @param _to: _to
     * @param _amount: _amount
     * @dev Only callable by the LiquidityMining.
     * @dev This function will be called by MasterChef contract, no need to revert.
     */
    function mintByLiquidityMining(address _to, uint256 _amount)
        external
        onlyLiquidityMining
    {
        if (liquidityMiningTotalSupply < LiquidityMiningMaxSupply) {
            uint256 mintAmount = (liquidityMiningTotalSupply + _amount) <
                LiquidityMiningMaxSupply
                ? _amount
                : (LiquidityMiningMaxSupply - liquidityMiningTotalSupply);
            liquidityMiningTotalSupply += mintAmount;
            _mint(_to, mintAmount);
        }
    }

    /**
     * @notice Mint by Staking
     * @param _to: _to
     * @param _amount: _amount
     * @dev Only callable by the Staking.
     * @dev This function will be called by staking contract, no need to revert.
     */
    function mintByStaking(address _to, uint256 _amount) external onlyStaking {
        if (stakingTotalSupply < StakingMaxSupply) {
            uint256 mintAmount = (stakingTotalSupply + _amount) <
                StakingMaxSupply
                ? _amount
                : (StakingMaxSupply - stakingTotalSupply);
            stakingTotalSupply += mintAmount;
            _mint(_to, mintAmount);
        }
    }

    /**
     * @notice Mint by Community
     * @param _to: _to
     * @param _amount: _amount
     * @dev Only callable by the Community.
     */
    function mintByCommunity(address _to, uint256 _amount)
        external
        onlyCommunity
    {
        require(
            communityTotalSupply < CommunityMaxSupply,
            "Exceeded maximum supply"
        );
        uint256 mintAmount = (communityTotalSupply + _amount) <
            CommunityMaxSupply
            ? _amount
            : (CommunityMaxSupply - communityTotalSupply);
        communityTotalSupply += mintAmount;
        _mint(_to, mintAmount);
    }

    /**
     * @notice Mint by Partnership
     * @param _to: _to
     * @param _amount: _amount
     * @dev Only callable by the Partnership.
     */
    function mintByPartnership(address _to, uint256 _amount)
        external
        onlyPartnership
    {
        require(
            partnershipTotalSupply < PartnershipMaxSupply,
            "Exceeded maximum supply"
        );
        uint256 mintAmount = (partnershipTotalSupply + _amount) <
            PartnershipMaxSupply
            ? _amount
            : (PartnershipMaxSupply - partnershipTotalSupply);
        partnershipTotalSupply += mintAmount;
        _mint(_to, mintAmount);
    }

    /**
     * @notice Mint by InitialLiquidity
     * @param _to: _to
     * @param _amount: _amount
     * @dev Only callable by the InitialLiquidity.
     */
    function mintByInitialLiquidity(address _to, uint256 _amount)
        external
        onlyInitialLiquidity
    {
        require(
            initialLiquidityTotalSupply < InitialLiquidityMaxSupply,
            "Exceeded maximum supply"
        );
        uint256 mintAmount = (initialLiquidityTotalSupply + _amount) <
            InitialLiquidityMaxSupply
            ? _amount
            : (InitialLiquidityMaxSupply - initialLiquidityTotalSupply);
        initialLiquidityTotalSupply += mintAmount;
        _mint(_to, mintAmount);
    }

    /**
     * @notice Mint by Team
     * @param _to: _to
     * @param _amount: _amount
     * @dev Only callable by the Team.
     */
    function mintByTeam(address _to, uint256 _amount) external onlyTeam {
        require(teamTotalSupply < TeamMaxSupply, "Exceeded maximum supply");
        uint256 mintAmount = (teamTotalSupply + _amount) < TeamMaxSupply
            ? _amount
            : (TeamMaxSupply - teamTotalSupply);
        teamTotalSupply += mintAmount;
        _mint(_to, mintAmount);
    }

    /**
     * @notice Sets LiquidityMining
     * @param _liquidityMining: _liquidityMining
     * @dev Only callable by the contract owner.
     */
    function setLiquidityMining(address _liquidityMining) external onlyOwner {
        require(_liquidityMining != address(0), "Cannot be zero address");
        LiquidityMining = _liquidityMining;
        emit NewLiquidityMining(_liquidityMining);
    }

    /**
     * @notice Sets Staking
     * @param _staking: _staking
     * @dev Only callable by the contract owner.
     */
    function setStaking(address _staking) external onlyOwner {
        require(_staking != address(0), "Cannot be zero address");
        Staking = _staking;
        emit NewStaking(_staking);
    }

    /**
     * @notice Sets Community
     * @param _community: _community
     * @dev Only callable by the contract owner.
     */
    function setCommunity(address _community) external onlyOwner {
        require(_community != address(0), "Cannot be zero address");
        Community = _community;
        emit NewCommunity(_community);
    }

    /**
     * @notice Sets Partnership
     * @param _partnership: _partnership
     * @dev Only callable by the contract owner.
     */
    function setPartnership(address _partnership) external onlyOwner {
        require(_partnership != address(0), "Cannot be zero address");
        Partnership = _partnership;
        emit NewPartnership(_partnership);
    }

    /**
     * @notice Sets InitialLiquidity
     * @param _initialLiquidity: _initialLiquidity
     * @dev Only callable by the contract owner.
     */
    function setInitialLiquidity(address _initialLiquidity) external onlyOwner {
        require(_initialLiquidity != address(0), "Cannot be zero address");
        InitialLiquidity = _initialLiquidity;
        emit NewInitialLiquidity(_initialLiquidity);
    }

    /**
     * @notice Sets Team
     * @param _team: _team
     * @dev Only callable by the contract owner.
     */
    function setTeam(address _team) external onlyOwner {
        require(_team != address(0), "Cannot be zero address");
        Team = _team;
        emit NewTeam(_team);
    }
}
