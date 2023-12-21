// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

pragma experimental ABIEncoderV2;

abstract contract DelegateERC20 is ERC20 {
    // @notice A record of each accounts delegate
    mapping(address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    // support delegates mint
    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);

        // add delegates to the minter
        _moveDelegates(address(0), _delegates[account], amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
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
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "DarkMatter::delegateBySig: invalid signature"
        );
        require(
            nonce == nonces[signatory]++,
            "DarkMatter::delegateBySig: invalid nonce"
        );
        require(
            block.timestamp <= expiry,
            "DarkMatter::delegateBySig: signature expired"
        );
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint32 nCheckpoints = numCheckpoints[account];
        return
            nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        returns (uint256)
    {
        require(
            blockNumber < block.number,
            "DarkMatter::getPriorVotes: not yet determined"
        );

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
            uint32 center = upper - (upper - lower) / 2;
            // ceil, avoiding overflow
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

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        // balance of underlying balances (not scaled);
        _delegates[delegator] = delegatee;

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);

        emit DelegateChanged(delegator, currentDelegate, delegatee);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0
                    ? checkpoints[srcRep][srcRepNum - 1].votes
                    : 0;
                uint256 srcRepNew = srcRepOld - (amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0
                    ? checkpoints[dstRep][dstRepNum - 1].votes
                    : 0;
                uint256 dstRepNew = dstRepOld + (amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal {
        uint32 blockNumber = safe32(
            block.number,
            "DarkMatter:_writeCheckpoint: block number exceeds 32 bits"
        );

        if (
            nCheckpoints > 0 &&
            checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(
                blockNumber,
                newVotes
            );
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint256 n, string memory errorMessage)
        internal
        pure
        returns (uint32)
    {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        return chainId;
    }

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );
}

// deflationary mechanism
interface DeflationController {
    function checkDeflation(
        address origin,
        address caller,
        address from,
        address recipient,
        uint256 amount
    ) external view returns (uint256);
}

// 𝓓𝓪𝓻𝓴  𝓜𝓪𝓽𝓽𝓮𝓻

contract DarkMatter is DelegateERC20, Pausable, Ownable {
    uint256 private constant _initialSupply = 9350000 * 1e18; // initial supply  minted 10.000.000 DMD (650k is minted for presale.)
    uint256 private constant _maxSupply = 85000000 * 1e18; // the maxSupply is 85.000.000 DMD
    uint256 private _burnTotal;

    address public deflationController;
    address public MasterChef;
    address public lockliquidity;
    address public presale;

    event SetDeflationController(address indexed _address);
    event SetMarterChef(address indexed _address);
    event Setlockliquidity(address indexed _address);

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;

    constructor() public ERC20("DarkMatter", "DMD") {
        _pause();
        _mint(msg.sender, _initialSupply);
    }

    function mint(address _to, uint256 _amount)
        public
        onlyMinter
        returns (bool)
    {
        if (_amount.add(totalSupply()) > _maxSupply) {
            // mint with max supply ---> only 85.000.000 DMD
            return false;
        }
        _mint(_to, _amount);
        return true;
    }

    function getinitialSupply() external pure returns (uint256) {
        return _initialSupply;
    }

    function getMaxSupply() external pure returns (uint256) {
        return _maxSupply;
    }

    function burn(uint256 _amount) external {
        _burn(address(msg.sender), _amount);
        _burnTotal = _burnTotal + _amount;
    }

    function burnTotal() public view returns (uint256) {
        return _burnTotal;
    }

    function setMasterChef(address _address) public onlyOwner {
        //Masterchef contract address.

        MasterChef = _address;
    }

    function setlockliquidity(address _address) public onlyOwner {
        //address where liquidity will be locked.

        lockliquidity = _address;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        uint256 toBurn = 0;

        if (address(0) != deflationController && amount > 0)
            toBurn = DeflationController(deflationController).checkDeflation(
                tx.origin,
                _msgSender(),
                _msgSender(),
                recipient,
                amount
            );

        if (toBurn > 0 && toBurn < amount) {
            amount = amount.sub(toBurn);
            _burn(_msgSender(), toBurn);
        }

        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function setDeflationController(address _address) external onlyOwner {
        // deflation controller contract address.

        deflationController = _address;
    }

    /**
     * @dev See {ERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override whenNotPaused returns (bool) {
        uint256 toBurn = 0;

        if (address(0) != deflationController && amount > 0)
            toBurn = DeflationController(deflationController).checkDeflation(
                tx.origin,
                _msgSender(),
                sender,
                recipient,
                amount
            );

        if (toBurn > 0 && toBurn < amount) {
            amount = amount.sub(toBurn);
            _burn(sender, toBurn);
        }

        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            allowance(sender, _msgSender()).sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function addMinter(address _addMinter) public onlyOwner returns (bool) {
        require(
            _addMinter != address(0),
            "DarkMatter: _addMinter is the zero address"
        );
        return EnumerableSet.add(_minters, _addMinter);
    }

    function removeMinter(address _removeMinter)
        public
        onlyOwner
        returns (bool)
    {
        require(
            _removeMinter != address(0),
            "DarkMatter: _removeMinter is the zero address"
        );
        return EnumerableSet.remove(_minters, _removeMinter);
    }

    function getMinterLength() public view returns (uint256) {
        return EnumerableSet.length(_minters);
    }

    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }

    function getMinter(uint256 _index) public view onlyOwner returns (address) {
        require(
            _index <= getMinterLength() - 1,
            "DarkMatter: index out of bounds"
        );
        return EnumerableSet.at(_minters, _index);
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender), "caller is not the minter");
        _;
    }

    //warning
    //The contract pause function will only be activated during the presale (why? "Some smart guy" could add the liquidity first than us giving a higher or lower price).
    // the owner of the token will be the Timelock and this function will not should be used at no time after the presale.

    function setPresale(address _presale) external onlyOwner {
        presale = _presale;
    }

    function unpause() external {
        require(msg.sender == presale, "DarkMatter: !presale");
        _unpause();
    }
}