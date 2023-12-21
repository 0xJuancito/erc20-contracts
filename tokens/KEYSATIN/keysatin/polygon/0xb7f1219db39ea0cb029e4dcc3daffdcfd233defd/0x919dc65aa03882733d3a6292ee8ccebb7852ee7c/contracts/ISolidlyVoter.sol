// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ISolidlyVoter {
    event Abstained(uint256 tokenId, int256 weight, address vault);
    event Attach(address indexed owner, address indexed sender, address indexed stakingToken, uint256 tokenId);
    event ContractInitialized(address controller, uint256 ts, uint256 block);
    event Detach(address indexed owner, address indexed sender, address indexed stakingToken, uint256 tokenId);
    event DistributeReward(address indexed sender, address indexed vault, uint256 amount);
    event Initialized(uint8 version);
    event NotifyReward(address indexed sender, uint256 amount);
    event RevisionIncreased(uint256 value, address oldLogic);
    event Voted(address indexed voter, uint256 tokenId, int256 weight, address vault, int256 userWeight, int256 vePower);

    function CONTROLLABLE_VERSION() external view returns (string memory);

    function MAX_VOTES() external view returns (uint256);

    function VOTER_VERSION() external view returns (string memory);

    function VOTE_DELAY() external view returns (uint256);

    function attachTokenToGauge(
        address stakingToken,
        uint256 tokenId,
        address account
    ) external;

    function attachedStakingTokens(uint256 veId) external view returns (address[] memory);

    function bribe() external view returns (address);

    function claimable(address) external view returns (uint256);

    function controller() external view returns (address);

    function created() external view returns (uint256);

    function createdBlock() external view returns (uint256);

    function detachTokenFromAll(uint256 tokenId, address account) external;

    function detachTokenFromGauge(
        address stakingToken,
        uint256 tokenId,
        address account
    ) external;

    function distribute(address _vault) external;

    function distributeAll() external;

    function distributeFor(uint256 start, uint256 finish) external;

    function gauge() external view returns (address);

    function increaseRevision(address oldLogic) external;

    function index() external view returns (uint256);

    function init(
        address _controller,
        address _ve,
        address _rewardToken,
        address _gauge,
        address _bribe
    ) external;

    function isController(address _value) external view returns (bool);

    function isGovernance(address _value) external view returns (bool);

    function isVault(address _vault) external view returns (bool);

    function lastVote(uint256) external view returns (uint256);

    function notifyRewardAmount(uint256 amount) external;

    function poke(uint256 _tokenId) external;

    function previousImplementation() external view returns (address);

    function reset(uint256 tokenId) external;

    function revision() external view returns (uint256);

    function supplyIndex(address) external view returns (uint256);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function token() external view returns (address);

    function totalWeight() external view returns (uint256);

    function updateAll() external;

    function updateFor(address[] memory _vaults) external;

    function updateForRange(uint256 start, uint256 end) external;

    function usedWeights(uint256) external view returns (uint256);

    function validVaults(uint256 id) external view returns (address);

    function validVaultsLength() external view returns (uint256);

    function vaultsVotes(uint256, uint256) external view returns (address);

    function _ve() external view returns (address);
    function ve() external view returns (address);

    function vote(
        uint256 tokenId,
        address[] memory _vaultVotes,
        int256[] memory _weights
    ) external;

    function votedVaultsLength(uint256 veId) external view returns (uint256);

    function votes(uint256, address) external view returns (int256);

    function weights(address) external view returns (int256);
}