// SPDX-License-Identifier: SimPL-2.0

pragma solidity ^0.8.0;

import "./Ownable2Step.sol";
import "./ERC20.sol";
import "./EnumerableSet.sol";

pragma experimental ABIEncoderV2;

abstract contract DelegateERC20 is ERC20 {
    // @notice A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }
    
    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;
    
    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;
    
    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    
    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    
    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;


    // support delegates mint
    function _mint(address account, uint256 amount) internal override virtual {
        super._mint(account, amount);
    
        // add delegates to the minter
        _moveDelegates(address(0), _delegates[account], amount);
    }


    function _transfer(address sender, address recipient, uint256 amount) internal override virtual {
        super._transfer(sender, recipient, amount);
        _moveDelegates(_delegates[sender], _delegates[recipient], amount);
    }

    /**
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }
    
    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    external
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );
    
        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );
    
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
    
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "BSCToken::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "BSCToken::delegateBySig: invalid nonce");
        require(block.timestamp <= expiry, "BSCToken::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }
    
    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
    external
    view
    returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }
    
    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
    external
    view
    returns (uint256)
    {
        require(blockNumber < block.number, "BSCToken::getPriorVotes: not yet determined");
    
        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }
    
        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }
    
        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }
    
        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }
    
    function _delegate(address delegator, address delegatee)
    internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying balances (not scaled);
        _delegates[delegator] = delegatee;
    
        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    
        emit DelegateChanged(delegator, currentDelegate, delegatee);
    }
    
    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }
    
            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }
    
    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
    internal
    {
        uint32 blockNumber = safe32(block.number, "BSCToken::_writeCheckpoint: block number exceeds 32 bits");
    
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }
    
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }
    
    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }
    
    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
    
        return chainId;
    }
    
    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    
    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

}

contract WindToken is DelegateERC20, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;
    uint256 public _maxSupply;

    uint256 public _newSupply;
    address public _ancestor;
    mapping(address => bool) internal _blacklist;

    event MinterUpdated(address indexed account, bool value);
    event BlacklistUpdated(address indexed account, bool value);
    event AncestorBurnt(uint256 amount);

    constructor(
        address ancestor,
        uint256 ancestorMaxSupply,
        uint256 newSupply
    ) ERC20("BinaryX", "BNX") {
        _ancestor = ancestor;
        _maxSupply = (ancestorMaxSupply * 100 + newSupply) * 1e18;
        _newSupply = newSupply * 1e18;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(amount <= _newSupply, "BSCToken: mint amount exceeds _newSupply");
        _mint(to, amount);
        _newSupply = _newSupply - amount;
    }
    
    function addMinter(address account) external onlyOwner returns (bool) {
        require(account != address(0), "BSCToken: account is the zero address");
        if (EnumerableSet.add(_minters, account)) {
            emit MinterUpdated(account, true);
            return true;
        }
        return false;
    }
    
    function delMinter(address account) external onlyOwner returns (bool) {
        require(account != address(0), "BSCToken: account is the zero address");
        if (EnumerableSet.remove(_minters, account)) {
            emit MinterUpdated(account, false);
            return true;
        }
        return false;
    }
    
    function getMinterLength() public view returns (uint256) {
        return EnumerableSet.length(_minters);
    }
    
    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }
    
    function getMinter(uint256 _index) external view onlyOwner returns (address){
        require(_index <= getMinterLength() - 1, "BSCToken: index out of bounds");
        return EnumerableSet.at(_minters, _index);
    }
    
    // modifier for mint function
    modifier onlyMinter() {
        require(isMinter(msg.sender), "caller is not the minter");
        _;
    }

    function burnAncestor(uint256 amount) external {
        address account = _msgSender();
        IERC20(_ancestor).transferFrom(account, address(0xdEaD), amount);
        _mint(account, amount * 100);
        emit AncestorBurnt(amount);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklist[account];
    }

    function blacklist(address account) external onlyOwner {
        _blacklist[account] = true;
        emit BlacklistUpdated(account, true);
    }

    function unblacklist(address account) external onlyOwner {
        _blacklist[account] = false;
        emit BlacklistUpdated(account, false);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!_blacklist[from], "BSCToken: from is blacklisted");
        require(!_blacklist[to], "BSCToken: to is blacklisted");
    }
}

