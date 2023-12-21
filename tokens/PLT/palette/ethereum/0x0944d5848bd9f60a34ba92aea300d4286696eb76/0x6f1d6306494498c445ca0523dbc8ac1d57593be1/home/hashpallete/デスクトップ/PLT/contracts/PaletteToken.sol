// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./erc20/ERC20Burnable.sol";
import "./access/OwnableWithAccept.sol";

/**
 * @title Palette token
 * @dev PLT, short for Palette Token, is the ERC20 token issued on
 * Ethereum. It's' convenient to be transferred to Palette Chain by
 * sending a cross-chain transaction on Ethereum which is based on 
 * Poly cross-chain ecosystem.
 */
contract PaletteToken is OwnableWithAccept, ERC20Burnable {
    enum ProposalStatus { Running, Pass, NotPass }

    struct Proposal {
        address proposer;
        uint256 mintAmount;
        uint256 lockedAmount;
        uint startTime;
        uint depositEndTime;
        uint votingEndTime;
        ProposalStatus status;
        string desc;
    }

    uint public proposalID;
    address public lockProxy;
    bytes public receiver;
    uint64 public ccID;
    bool public isFreezed;
    uint public duration;
    uint public durationLimit;
   
    mapping(uint => mapping(address=>uint256)) public stakeTable;
    mapping(uint => uint256) public stakeCounter;
    mapping(uint => mapping(address => uint256)) public voteBox;
    mapping(uint => uint256) public voteCounter;
    mapping(uint => Proposal) public proposals;
    mapping(address => uint[]) internal whoseProposals;
    mapping(address => uint[]) internal deposited;
    mapping(address => mapping(uint => uint)) depositedIndex;

    event Vote(address indexed voter, uint indexed proposalID, uint256 amount);
    event CancelVote(address indexed voter, uint indexed proposalID, uint256 amount);
    event ProposalPass(uint indexed proposalID, uint256 value);
    event ProposalFail(uint indexed proposalID, uint256 totalVote , uint256 limitToPass);
    event ProposalMake(uint indexed proposalID, address indexed sender, uint256 mintAmount, uint startTime, uint depositEndTime, uint votingEndTime, uint256 lockedAmount, string desc);
    event Deposit(address indexed from, uint indexed proposalID, uint256 amount);
    event Withdraw(address indexed from, uint indexed proposalID, uint256 amount);

    modifier whenNotFreezed() {
        require(!isFreezed, "you can not call this func when contract is freezed");
        _;
    }

    modifier whenFreezed() {
        require(isFreezed, "you can only call this func when contract is freezed");
        _;
    }

    function initialize() public initializer {
        initializeOwner();
        initializeERC20("Palette Token", "PLT");
        _mint(_msgSender(), 1000000000 * 10 ** uint256(decimals()));
        isFreezed = true;
        duration = 2 weeks;
        proposalID = 1;
        durationLimit = 1 days;
    }

    /**
     * @dev Constructor, initialize the basic information of contract.
     */
    constructor() public ERC20Initializable("Palette Token", "PLT") {
        initialize();
    }

    /**
     * @dev Set lock proxy address where crosschain PLT will locked in.
     * @param newLockProxy lock proxy contract address
     */
    function setLockProxy(address newLockProxy) public onlyOwner whenFreezed {
        lockProxy = newLockProxy;
    }

    /**
     * @dev Set palette receiver who receive the crosschain PLT.
     * @param newReceiver Palette chain address
     */
    function setPaletteReceiver(bytes memory newReceiver) public onlyOwner whenFreezed {
        receiver = newReceiver;
    }

    /**
     * @dev Set cross chain ID of Palette Chain.
     * @param chainID Palette chain ID
     */
    function setCrossChainID(uint64 chainID) public onlyOwner whenFreezed {
        ccID = chainID;
    }

    /**
     * @dev Set contract freezed and no issuing proposals can be make or execute.
     */
    function freeze() public onlyOwner whenNotFreezed {
        isFreezed = true;
    }

    /**
     * @dev Set contract unfreezed.
     */
    function unFreeze() public onlyOwner whenFreezed {
        require(lockProxy != address(0), "lock proxy is not set");
        require(receiver.length > 0, "palette operator is not set");
        require(ccID > 0, "palette chain id is zero");
        isFreezed = false;
    }

    /**
     * @dev Set duration length for deposit and voting duration.
     * default 2 weeks.
     * @param _duration duration length
     */
    function setDuration(uint _duration) public onlyOwner {
        require(_duration >= durationLimit, "at least one day");
        duration = _duration;
    }

    /** 
     * @dev It's not recommended to change limit of duration. The limit 
     * is 1 day by default.
     * @param limit new limit of duration.
     */
    function setDurationLimit(uint limit) public onlyOwner {
        durationLimit = limit;
    }

    /**
     * @dev the next owner must call this function to accept the ownership
     */
    function acceptOwnership() override public {
        address nextOwner = getNextOwner();
        require(nextOwner != address(0), "get zero next owner");
        require(_msgSender() == nextOwner, "you are not next owner");
        
        address old = owner();
        uint256 bal = balanceOf(old);
        _transfer(old, nextOwner, bal);
        super.acceptOwnership();

        uint[] memory ids = deposited[old];
        uint len = ids.length;
        if (len > 0) {
            for (uint index = 0; index < len; index++) {
                uint k = ids[index];
                if (depositedIndex[nextOwner][k] == 0) {
                    deposited[nextOwner].push(k);
                    depositedIndex[nextOwner][k] = deposited[nextOwner].length;
                }
                stakeTable[k][nextOwner] = stakeTable[k][old];
                voteBox[k][nextOwner] = voteBox[k][old];
                delete stakeTable[k][old];
                delete voteBox[k][old];
                delete depositedIndex[old][k];
            }
            delete deposited[old];
        }

        ids = getHisProposals(old);
        if (ids.length > 0) {
            for (uint index = 0; index < ids.length; index++) {
                proposals[ids[index]].proposer = nextOwner;
                whoseProposals[nextOwner].push(ids[index]);
            }
            delete whoseProposals[old];
        }
    }

    /**
     * @dev When you want to mint more PLT to the Palette Chain, 
     * you need to **make a proposal** in PLT contract with some PLT 
     * locked by calling `makeProposal()`. To do that , you need at
     *  least 1% of total supply in your account. This proposal will
     *  be made with a `proposalID` which is increasing from 1.
     * It will be released when this proposal executed. 
     * @param mintAmount amount to be minted of PLT
     * @param desc description for this proposal
     * @param startTime when proposal start
     */
    function makeProposal(uint256 mintAmount, string memory desc, uint startTime) public whenNotFreezed returns (uint256) {
        require(bytes(desc).length <= 128, "length of description must be less than 128");
        uint256 deposit = totalSupply().div(100);
        uint256 bal = balanceOf(_msgSender());
        require(bal >= deposit, "you need to lock one percent PLT of total supply to create a proposal which you don't have.");
        require(mintAmount > 0, "mintAmount must be greater than 0");

        if (startTime < now) {
            startTime = now;
        }

        Proposal memory p;
        p.mintAmount = mintAmount;
        p.startTime = startTime;
        p.depositEndTime = startTime + duration;
        p.votingEndTime = startTime + 2 * duration;
        p.desc = desc;
        p.status = ProposalStatus.Running;
        p.proposer = _msgSender();
        p.lockedAmount = deposit;

        proposals[proposalID] = p;
        whoseProposals[_msgSender()].push(proposalID);
        require(transfer(address(this), deposit), "failed to lock your PLT to contract");
        emit ProposalMake(proposalID, _msgSender(), mintAmount, startTime, p.depositEndTime, p.votingEndTime, p.lockedAmount, desc);
        proposalID++;

        return proposalID - 1;
    }

    /**
     * @dev After proposal made, everyone holding the PLT 
     * can call `deposit()` to lock their PLT for this proposal. 
     * There is two weeks to deposit after proposal made. 
     * No one can deposit again if over time. We call this 
     * duration as **Deposit Duration**.
     * You can withdraw your PLT after this proposal executed.
     * @param id proposal ID 
     * @param amount amount of PLT you want to lock for this proposal
     */
    function deposit(uint id, uint256 amount) public whenNotFreezed {
        require(amount > 0, "amount must bigger than zero");
        require(proposalID > id, "this proposal is not exist!");
        
        Proposal memory p = proposals[id];
        require(p.startTime <= now, "this proposal is not start yet");
        require(p.depositEndTime > now, "this proposal is out of stake duration");

        uint256 bal = balanceOf(_msgSender());
        require(bal >= amount, "your PLT is not enough to lock");

        require(transfer(address(this), amount), "failed to lock your PLT to contract");
        stakeTable[id][_msgSender()] = stakeTable[id][_msgSender()].add(amount);
        stakeCounter[id] = stakeCounter[id].add(amount);
        if (depositedIndex[_msgSender()][id] == 0) {
            deposited[_msgSender()].push(id);
            depositedIndex[_msgSender()][id] = deposited[_msgSender()].length;
        }

        emit Deposit(_msgSender(), id, amount);
    }

    /**
     * @dev After Deposit Duration, this proposal will move into
     * **Voting Duration**. During this time, everyone who deposit 
     * their PLT would get some **stake** which is same number as 
     * their locked PLT. And only people hold the stake can vote for 
     * this proposal. Call `vote()` to vote **yes** for this proposal. 
     * If you hold stake and don't vote during Voting Duration, it
     *  means you don't support this proposal.
     * @param id proposal ID 
     * @param amount amount of stake you want to vote for this proposal
     */
    function vote(uint id, uint256 amount) public whenNotFreezed {
        require(proposalID > id, "this proposal is not exist!");
        require(amount > 0, "amount must bigger than zero");
        require(stakeCounter[id] > totalSupply().div(10), "no need to vote because of the locked amount is less than 10% PLT");

        Proposal memory p = proposals[id];
        require(now >= p.depositEndTime, "this proposal is not start yet");
        require(now < p.votingEndTime, "this proposal is already out of vote duration");
        require(stakeTable[id][_msgSender()] >= amount, "you locked stake is not enough to vote in this amount");

        voteBox[id][_msgSender()] = voteBox[id][_msgSender()].add(amount);
        voteCounter[id] = voteCounter[id].add(amount);
        stakeTable[id][_msgSender()] = stakeTable[id][_msgSender()].sub(amount);

        emit Vote(_msgSender(), id, amount);
    }

    /**
     * @dev During voting duration, you can cancel you vote for this proposal
     * and get your stake back.
     * @param id proposal ID 
     * @param amount amount of stake voted you want to withdraw
     */
    function cancelVote(uint id, uint256 amount) public whenNotFreezed {
        require(proposalID > id, "this proposal is not exist!");
        Proposal memory p = proposals[id];
        require(now >= p.depositEndTime, "vote of this proposal is not start yet");
        require(now < p.votingEndTime, "this proposal is already out of vote duration");
        require(voteBox[id][_msgSender()] >= amount, "you voted stake is not enough for this amount");

        voteBox[id][_msgSender()] = voteBox[id][_msgSender()].sub(amount);
        voteCounter[id] = voteCounter[id].sub(amount);
        stakeTable[id][_msgSender()] = stakeTable[id][_msgSender()].add(amount);

        emit CancelVote(_msgSender(), id, amount);
    }

    /**
     * @dev When Voting Duration is over, everyone can trigger the 
     * **execution for this proposal** which will determine it success 
     * or failure by calling `excuteProposa()`. If the voted stake is bigger 
     * than the 2/3 of total stake for this proposal, this proposal will 
     * execute successfully. So more PLT will be minted. Whatever the result, 
     * the locked PLT will be returned to the proposer of this proposal.
     * @param id proposal ID 
     */
    function excuteProposal(uint id) public whenNotFreezed {
        require(proposalID > id, "this proposal is not exist!");
        require(lockProxy != address(0), "lock proxy is zero address");
        require(ccID != 0, "cross chain ID of Palette Chain is zero");
        require(receiver.length > 0, "palette operator is zero address");

        Proposal memory p = proposals[id];
        require(p.votingEndTime < now, "it's still in voting");
        require(p.status == ProposalStatus.Running, "proposal is not running");
       
        _transfer(address(this), p.proposer, p.lockedAmount);
        uint256 limit = stakeCounter[id].mul(2).div(3) + 1;
        if (voteCounter[id] < limit || stakeCounter[id] < totalSupply().div(10)) {
            proposals[id].status = ProposalStatus.NotPass;
            emit ProposalFail(id, voteCounter[id], limit);
            return;
        }

        proposals[id].status = ProposalStatus.Pass;
        
        _mint(address(this), p.mintAmount);
        emit ProposalPass(id, p.mintAmount);
        
        delete voteCounter[id];
        delete stakeCounter[id];

        // lock proxy must be approved to use these PLT
        // because proxy use transferFrom to lock the asset.
        _approve(address(this), lockProxy, p.mintAmount);

        bool ok;
        bytes memory res;
        // first we need to check if proxy already set Palette Chain
        bytes memory checkAsset = abi.encodeWithSignature("assetHashMap(address,uint64)", address(this), ccID);
        (ok, res) = lockProxy.call(checkAsset);
        require(ok, "failed to call assetHashMap()");
        require(res.length > 64, "no asset binded for PLT");

        // call lock() to lock the PLT and cross-chain start
        // please check https://github.com/polynetwork/eth-contracts/blob/c9212e4199432b0ea6e0defff390e804afe07a32/contracts/core/lock_proxy/LockProxy.sol#L64
        bytes memory lock = abi.encodeWithSignature("lock(address,uint64,bytes,uint256)", address(this), ccID, receiver, p.mintAmount);
        (ok, ) = lockProxy.call(lock);
        require(ok, "failed to call lock() of lock proxy contract");
    } 

    /**
     * @dev After proposal executed, everyone who deposit to get
     *  stake can **withdraw** their locked PLT by calling `withdraw()`. 
     * @param id proposal ID 
     */
    function withdraw(uint id) public whenNotFreezed { 
        require(proposalID > id, "this proposal is not exist!");
        Proposal memory p = proposals[id];
        require(p.status != ProposalStatus.Running, "you can not unlock your stake until proposal is excuted. ");
        require(p.votingEndTime < now, "it's still in voting");

        uint256 amt = stakeTable[id][_msgSender()].add(voteBox[id][_msgSender()]);
        require(amt > 0, "you have no stake for this proposal");

        _transfer(address(this), _msgSender(), amt);
        delete stakeTable[id][_msgSender()];
        delete voteBox[id][_msgSender()];
        
        uint idx = depositedIndex[_msgSender()][id] - 1;
        uint last = deposited[_msgSender()].length - 1;
        uint lastID = deposited[_msgSender()][last];
        deposited[_msgSender()][idx] = lastID;
        deposited[_msgSender()].pop();
        depositedIndex[_msgSender()][lastID] = idx;
        delete depositedIndex[_msgSender()][id];

        emit Withdraw(_msgSender(), id, amt);
    }

    /**
     * @dev Is now good to vote for a proposal.
     * @param id proposal ID 
     */
    function isGoodToVote(uint id) public view returns (bool) {
        if (proposalID <= id) {
            return false;
        }
        Proposal memory p = proposals[id];
        return p.votingEndTime > now && p.depositEndTime <= now;
    }

    /**
     * @dev Is now good to deposit for a proposal.
     * @param id proposal ID 
     */
    function isGoodToDeposit(uint id) public view returns (bool) {
        if (proposalID <= id) {
            return false;
        }
        Proposal memory p = proposals[id];
        return p.depositEndTime > now && p.startTime <= now;
    }

    /**
     * @dev Your total stake for a proposal.
     * @param id proposal ID 
     */
    function myTotalStake(uint id) public view returns (uint256) {
        return stakeTable[id][_msgSender()].add(voteBox[id][_msgSender()]);
    }

    /**
     * @dev Get all proposals' id made by this address.
     * @param he address to search
     */
    function getHisProposals(address he) public view returns (uint[] memory) {
        return whoseProposals[he];
    }

    /**
     * @dev Get all proposals' id deposited by this address.
     * @param he address to search
     */
    function getHisDepositedID(address he) public view returns (uint[] memory) {
        return deposited[he];
    }
}