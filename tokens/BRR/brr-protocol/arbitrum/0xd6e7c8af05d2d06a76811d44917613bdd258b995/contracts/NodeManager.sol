pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Brr.sol";
import "./Utils.sol";
import "./RewardPool.sol";
import "hardhat/console.sol";

// add owner recovery upgradeable

contract Manager is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    Utils
{
    struct NodeEntity {
        uint256 id;
        string name;
        uint256 tier;
        bool exists;
        uint256 creationTime;
        uint256 lastClaimTime;
        uint256 totalClaimed;
        uint256 accumulatedRewards;
        bool hasBonus;
        bool isOg;
    }

    struct TierStorage {
        uint256 rewards;
        uint256 price;
        bool exists;
        string name;
        string dailyRewards;
        uint256 claimTax; // percentage
        string imageURI;
        uint256 upgradeTime;
        uint256 noClaimBonus; // percentage
        uint256 totalNodes;
    }

    uint256 private maxHighTier;
    uint256 public _nodeCounter;
    mapping(uint256 => NodeEntity) private _nodes;
    uint256 public _tierTracked;
    mapping(uint256 => TierStorage) private _tierTracking;
    mapping(address => bool) private _ogs;

    uint256 public totalValueLocked;
    uint256 public burnedFrom;

    bool public isPaused;

    RewardPool private rewardPool;
    address public treasuryWallet;

    uint256 nameChangePrice;

    uint private burnRate;
    uint private poolRate;
    uint private treasuryRate;

    Brr public brr;

    mapping(address => bool) private _transferOperators;
    mapping(address => bool) private _operators;
    bool public toggleMarketplace;
    mapping(address => bool) private _requested;

    modifier onlyOperator(){
        require(_operators[msg.sender], "Not operator on the manager");
        _;
    }

    modifier onlyNodeOwner() {
        address sender = msg.sender;
        require(sender != address(0), "Node: Sender cannot be zero address");
        require(isNodeOwner(sender), "Node: Not owner of any node");
        _;
    }

    modifier canUpgrade(uint256 _nodeId) {
        NodeEntity memory node = _nodes[_nodeId];
        TierStorage memory tier = _tierTracking[node.tier];
        require((node.lastClaimTime + tier.upgradeTime < block.timestamp) || (node.isOg && node.tier == 0 &&  (node.lastClaimTime + (tier.upgradeTime / 2) > block.timestamp)), "Node: You cannot yet upgrade");
        _;
    }

    modifier checkPermissions(uint256 _nodeId) {
        require(isNodeValid(_nodeId), "Node: Given node does not exist");
        require(
            isApprovedOrOwner(msg.sender, _nodeId),
            "Node: You are not approved or owner of this node"
        );
        _;
    }

    modifier checkPermissionsMultiple(uint256[] memory _nodeIds) {
        address sender = msg.sender;
        for (uint256 i = 0; i < _nodeIds.length; increment(i)) {
            require(
                isNodeValid(_nodeIds[i]),
                "Node: Given node does not exist"
            );
            require(
                isApprovedOrOwner(msg.sender, _nodeIds[i]),
                "Node: You are not approved or owner of this node"
            );
        }
        _;
    }

    modifier verifyName(string memory nodeName) {
        require(
            bytes(nodeName).length > 1 && bytes(nodeName).length < 32,
            "Node: Name should between 2 to 31"
        );
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Node: Contract is paused");
        _;
    }

    modifier tierValid(uint256 _tier) {
        require(_tier <= _tierTracked, "Node: Tier does not exist");
        _;
    }

    event Upgrade(
        address indexed account,
        uint256 indexed nodeId,
        uint256 tier
    );
    event Claim(
        address indexed account,
        uint256 indexed nodeId,
        uint256 rewardAmount
    );

    event Create(
        address indexed account,
        uint256 indexed newNodeId,
        uint256 tier
    );

    event Rename(
        address indexed account,
        string indexed previousName,
        string indexed newName
    );

    function initialize(address _brr, address _rewardPool, uint _burnRate, uint _poolRate, uint _treasuryRate) external initializer {
        __ERC721_init("Brr Nodes", "NODE");
        __Ownable_init();
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        toggleMarketplace = false;
        _operators[msg.sender] = true;
        rewardPool = RewardPool(_rewardPool);
        brr = Brr(_brr);
        burnRate = _burnRate;
        poolRate = _poolRate;
        treasuryRate = _treasuryRate;
        maxHighTier = 50;
    }

    /* EXTERNAL PUBLIC FUNCTION */
    function createNode(string memory _nodeName)
        external
        notPaused
        returns (uint256)
    {
        TierStorage storage tier = _tierTracking[0];
        tier.totalNodes += 1;
        address sender = msg.sender;
        brr.transferFrom(sender, address(this), tier.price);
        // 30% burn, 60% reward pool, 10% treasury
        _dispatchTokens(tier.price, burnRate, poolRate, treasuryRate);
        return _createNode(sender, _nodeName, 0);
    }

    function upgradeNode(uint256 _nodeId)
        external
        onlyNodeOwner
        checkPermissions(_nodeId)
        notPaused
        canUpgrade(_nodeId)
    {
        address sender = msg.sender;
        NodeEntity storage node = _nodes[_nodeId];

        // Make sure next tier exist
        require(
            node.tier + 1 <= _tierTracked,
            "Node: Tier does not exist for upgrade"
        );
        
        // New tier
        uint256 _tier = node.tier + 1;
        if (_tier >= 5) require(getTierCirculating(_tier) <= maxHighTier, 'Maximum high tier circulating supply reached');
        // Update node tracking total nodes
        _tierTracking[node.tier].totalNodes -= 1;
        _tierTracking[_tier].totalNodes += 1;
        // Transfer BRR & dispatch tokens: 30% burn, 60% reward pool, 10% treasury 
        brr.transferFrom(sender, address(this), _tierTracking[_tier].price);
        _dispatchTokens(_tierTracking[_tier].price, burnRate, poolRate, treasuryRate);
        // Update node tier
        node.tier = _tier;
        // Update node rewards
        node.accumulatedRewards = getPendingRewards(_nodeId);
        // Update last claim time
        node.lastClaimTime = block.timestamp;
        // Claim rewards for node
        // _claimRewards(sender, _nodeId);

        if (!_operators[sender]) emit Upgrade(sender, _nodeId, _tier);
    }

    function claimRewards(uint256 _nodeId)
        external
        onlyNodeOwner
        checkPermissions(_nodeId)
        notPaused
    {
        _claimRewards(msg.sender, _nodeId);
        // lose the bonus forever, only after its claimed
        NodeEntity storage node = _nodes[_nodeId];
        if (node.tier < 5) node.hasBonus = false;        
    }

    /* EXTERNAL OPERATOR FUNCTIONS */
    function changeTier(
        uint256 _tierId,
        uint256 _tierRewards,
        uint256 _tierPrice,
        string memory _tierName,
        string memory _dailyRewards,
        uint256 _claimTax,
        string memory _imageURI,
        uint256 _upgradeTime,
        uint256 _noClaimBonus
    ) public onlyOperator{
        require(_tierId <= _tierTracked, 'Too far bro');
        _tierTracking[_tierId] = TierStorage({
            rewards: _tierRewards,
            price: _tierPrice,
            exists: true,
            name: _tierName,
            claimTax: _claimTax,
            dailyRewards: _dailyRewards,
            imageURI: _imageURI,
            upgradeTime: _upgradeTime,
            noClaimBonus: _noClaimBonus,
            totalNodes: 0
        });
        if (_tierId == _tierTracked) _tierTracked = increment(_tierTracked);
    }

    function setRates(uint burn, uint pool, uint treasury) external onlyOperator{
        burnRate = burn;
        poolRate = pool;
        treasuryRate = treasury;
    }

    function registerOgs(address[] memory ogList) external onlyOperator{
        for(uint i = 0; i < ogList.length; i++){
            _ogs[ogList[i]] = true;
        }
    }

    function createNodeAdmin(
        string memory _nodeName,
        uint256 _tier,
        address _user 
    ) public onlyOperator {
        _createNode(_user, _nodeName, _tier);
    }

    function setMaxHighTier(uint256 max) external onlyOperator{ 
        maxHighTier = max;
    }

    function setWallets(
        address _rewardPool,
        address _treasury
    ) public onlyOperator{
        rewardPool = RewardPool(_rewardPool);
        treasuryWallet = _treasury;
    }

    function setToken(address _token) public onlyOperator{
        brr = Brr(_token);
    }

    function setToggleMarketplace(bool _toggle) public onlyOperator{
        toggleMarketplace = _toggle;
    }

    function setOperator(address _operator, bool value) public onlyOperator{
        _operators[_operator] = value;
    }

    function setRewardPool(address _rewardPool) public onlyOperator{
        rewardPool = RewardPool(_rewardPool);
    }

    function setTransferOperator(address operator, bool value) public onlyOperator{
        _transferOperators[operator] = value;
    }

    /* INTERNAL FUNCTIONS */
    function _dispatchTokens(
        uint256 amount,
        uint256 _burnPercent,
        uint256 _rewardPoolPercent,
        uint256 _treasuryPercent
    ) internal {
        if (_burnPercent > 0 ) {
            brr.burn(getPercentageOf(amount, _burnPercent));
        }
        if (_rewardPoolPercent > 0){
            brr.transfer(address(rewardPool), getPercentageOf(amount, _rewardPoolPercent));
        }
        if (_treasuryPercent > 0){
            brr.transfer(address(treasuryWallet), getPercentageOf(amount, _treasuryPercent));
        }
    }

    function _createNode(
        address user,
        string memory _nodeName,
        uint256 _tier
    ) internal verifyName(_nodeName) tierValid(_tier) returns (uint256) {
        _nodeCounter = increment(_nodeCounter);
        uint256 newNodeId = _nodeCounter;
        uint256 currentTimestamp = block.timestamp;
        _nodes[newNodeId] = NodeEntity({
            id: newNodeId,
            name: _nodeName,
            creationTime: currentTimestamp,
            lastClaimTime: currentTimestamp,
            totalClaimed: 0,
            tier: _tier,
            exists: true,
            accumulatedRewards: 0,
            hasBonus: true,
            isOg: _ogs[user]
        });
        _mint(user, newNodeId);
        if(!_operators[user]) Create(user, newNodeId, _tier);
        return newNodeId;
    }

    function _claimRewards(address user, uint256 _nodeId) internal {
        uint256 pendingRewards = getTotalRewards(_nodeId);
        require(
            pendingRewards > 0,
            "Node: You do not have any pending rewards"
        );

        NodeEntity storage node = _nodes[_nodeId];

        node.lastClaimTime = block.timestamp;
        node.totalClaimed += pendingRewards;
        node.accumulatedRewards = 0;

        uint tax = getPercentageOf(pendingRewards, _tierTracking[node.tier].claimTax);
        rewardPool.emitRewards(user, pendingRewards - tax);
        if (tax > 0){
            rewardPool.emitRewards(treasuryWallet, tax);
        }
        if (!_operators[user]) emit Claim(user, _nodeId, pendingRewards);
    }

    /* PUBLIC VIEW FUNCTION */
    function getNodeName(uint256 _nodeId) public view returns (string memory) {
        return _nodes[_nodeId].name;
    }

    function getNodeUpgradeTimeLeft(uint256 _nodeId) public view returns (uint256){
        NodeEntity memory node = _nodes[_nodeId];
        uint256 timeLeft = (node.lastClaimTime + _tierTracking[node.tier].upgradeTime) - block.timestamp;
       if (timeLeft <= 0) return 0;
       return timeLeft;
    }

    function getTierCirculating(uint256 _tierId) public view returns(uint256){
        return _tierTracking[_tierId].totalNodes;
    }

    function getTierInfo(uint256 _tierId) public view returns(uint256, string memory, uint256, uint256, uint256, uint256){
        TierStorage memory tier = _tierTracking[_tierId];
        return (tier.totalNodes, tier.dailyRewards, tier.price, tier.claimTax, tier.noClaimBonus, tier.upgradeTime);
    } 

    function getNodesUpgradeTimeLeft(address user) public view returns (string memory){
        string memory result;
        string memory separator = "#";
        uint256[] memory userNodes = getNodeIdsOf(user);
        for (uint256 i = 0; i < userNodes.length; i = increment(i)) {
            uint256 timeLeft = getNodeUpgradeTimeLeft(userNodes[i]);
            result = string(abi.encodePacked(result, separator, uint2str(timeLeft)));
        }
        return result; 
    }

    function getNodesName(address user) public view returns (string memory) {
        string memory result;
        string memory separator = "#";
        uint256[] memory userNodes = getNodeIdsOf(user);
        for (uint256 i = 0; i < userNodes.length; i = increment(i)) {
            string memory name = getNodeName(userNodes[i]);
            result = string(abi.encodePacked(result, separator, name));
        }
        return result;
    }

    function getPendingRewards(uint256 _nodeId) public view returns (uint256) {
        NodeEntity memory node = _nodes[_nodeId];
        uint256 tierRewards = _tierTracking[node.tier].rewards;
        uint256 redeemTime = block.timestamp - node.lastClaimTime;
        uint pending = redeemTime * tierRewards;
        // has bonus?
        if (node.hasBonus && node.tier > 1){
            uint bonusRewards = getPercentageOf(pending, _tierTracking[node.tier].noClaimBonus);
            pending += bonusRewards;
        }
        return redeemTime * tierRewards;
    }

    function getTotalRewards(uint256 _nodeId) public view returns(uint256){
        return getPendingRewards(_nodeId) + _nodes[_nodeId].accumulatedRewards;
    }

    function getNodesRewards(address user) public view returns (string memory) {
        string memory result;
        string memory separator = "#";
        uint256[] memory userNodes = getNodeIdsOf(user);
        for (uint256 i = 0; i < userNodes.length; i = increment(i)) {
            uint256 rewards = getPendingRewards(userNodes[i]);
            result = string(
                abi.encodePacked(result, separator, uint2str(rewards))
            );
        }
        return result;
    }

    function getNodesTiers(address user) public view returns( string memory){
        string memory result;
        string memory separator = "#";
        uint256[] memory userNodes = getNodeIdsOf(user);
        for (uint256 i = 0; i < userNodes.length; i = increment(i)) {
            uint256 tier = _nodes[userNodes[i]].tier;
            result = string(abi.encodePacked(result, separator, uint2str(tier)));
        }
        return result;
    }

    // Get tier name from node id
    function getTierName(uint256 _nodeId) public view returns (string memory) {
        return _tierTracking[_nodes[_nodeId].tier].name;
    }

    function isNodeOwner(address _user) public view returns (bool) {
        return balanceOf(_user) > 0;
    }

    function isApprovedOrOwner(address _user, uint256 _nodeId)
        public
        view
        returns (bool)
    {
        return _isApprovedOrOwner(_user, _nodeId);
    }

    function isNodeValid(uint256 _nodeId) public view returns (bool) {
        require(_nodeId >= 0, "Node: Id must be equal or higher than zero");
        return _nodes[_nodeId].exists;
    }

    // Get daily reward of tier from node id
    function getDailyReward(uint256 _nodeId)
        public
        view
        returns (string memory)
    {
        return _tierTracking[_nodes[_nodeId].tier].dailyRewards;
    }

    // Get imageURI of tier from node id
    function getTierImageURI(uint256 _nodeId)
        public
        view
        returns (string memory)
    {
        return _tierTracking[_nodes[_nodeId].tier].imageURI;
    }

    function printAttributes(uint256 _nodeId)
        public
        view
        returns (string memory)
    {
        uint256 pendingRewards = getPendingRewards(_nodeId) / (1e18);
        bytes memory data = "";
        data = abi.encodePacked(
            data,
            '{"trait_type":"',
            "Pending Rewards",
            '","value":"',
            uint2str(pendingRewards),
            " BRR",
            '"}'
        );
        return string(data);
    }

    // TODO: Implement on chain meaadata
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                "{",
                                '"name": "',
                                getTierName(tokenId),
                                ": ",
                                getNodeName(tokenId),
                                '",',
                                '"description": "This scammer is making ',
                                getDailyReward(tokenId),
                                ' BRR daily",',
                                '"attributes": [',
                                printAttributes(tokenId),
                                "],",
                                '"image":"',
                                getTierImageURI(tokenId),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function getUserRewards(address account)
        public
        view
        returns (string memory)
    {
        string memory result;
        string memory separator = "#";
        uint256[] memory userNodes = getNodeIdsOf(account);
        for (uint256 i = 0; i < userNodes.length; i = increment(i)) {
            uint256 rewards = getTotalRewards(userNodes[i]);
            result = string(abi.encodePacked(result, separator, uint2str(rewards)));
        }
        return result; 
    }

    function getTotalPendingRewards(address account)
        public
        view
        returns (uint256)
    {
        uint256 totalRewards;
        uint256[] memory userNodes = getNodeIdsOf(account);
        for (uint256 i = 0; i < balanceOf(account); i = increment(i)) {
            totalRewards += getPendingRewards(userNodes[i]);
        }
        return totalRewards;
    }

    function getNodeIdsOf(address account)
        public
        view
        returns (uint256[] memory)
    {
        uint256 nodeNumber = balanceOf(account);
        uint256[] memory nodeIds = new uint256[](nodeNumber);
        for (uint256 i = 0; i < nodeNumber; i = increment(i)) {
            uint256 nodeId = tokenOfOwnerByIndex(account, i);
            require(isNodeValid(nodeId), "Node: Given node id does not exist");
            nodeIds[i] = nodeId;
        }
        return nodeIds;
    }

    // Override on transferFrom for marketplace
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        if (toggleMarketplace)
            require(_transferOperators[msg.sender], "Not operator on transfer");    
        _transfer(from, to, tokenId);
    }

    // Mandatory overrides

    function _burn(uint256 tokenId)
        internal
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
    {
        NodeEntity storage node = _nodes[tokenId];
        node.exists = false;
        ERC721Upgradeable._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
