// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "../interfaces/IXMSToken.sol";
import "../refs/CoreRef.sol";

// XMSToken with Governance.
contract XMSToken is IXMSToken, CoreRef {
    string public constant override name = "Mars Ecosystem Token";

    string public constant override symbol = "XMS";

    uint8 public constant override decimals = 18;

    /// @notice Total number of tokens in circulation
    uint256 public override totalSupply = 1_000_000_000e18;

    // Allowance amounts on behalf of others
    mapping(address => mapping(address => uint96)) internal _allowances;

    // Official record of token balances for each account
    mapping(address => uint96) internal _balances;

    /// @notice A record of each accounts delegate
    mapping(address => address) public override delegates;

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

    /// @notice The EIP-712 typehash for the permit struct used by the contract
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    constructor(address _treasury, address _core) CoreRef(_core) {
        _balances[_treasury] = uint96(totalSupply);
        emit Transfer(address(0), _treasury, totalSupply);
    }

    function mint(address _to, uint256 _amount) external override onlyGovernor {
        require(_to != address(0), "XMSToken::mint: Zero address");
        uint96 amount =
            safe96(_amount, "XMSToken::mint: Amount exceeds 96 bits");
        uint96 safeSupply =
            safe96(totalSupply, "XMSToken::mint: TotalSupply exceeds 96 bits");
        totalSupply = add96(
            safeSupply,
            amount,
            "XMSToken::mint: TotalSupply exceeds 96 bits"
        );

        // transfer the amount to the recipient
        _balances[_to] = add96(
            _balances[_to],
            amount,
            "XMSToken::mint: Transfer amount overflows"
        );
        emit Transfer(address(0), _to, amount);

        // move delegates
        _moveDelegates(address(0), delegates[_to], amount);
    }

    /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param account The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address account, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[account][spender];
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `msg.sender`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (2^256-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        uint96 amount_;
        if (amount == uint256(-1)) {
            amount_ = uint96(-1);
        } else {
            amount_ = safe96(
                amount,
                "XMSToken::approve: Amount exceeds 96 bits"
            );
        }

        _allowances[msg.sender][spender] = amount_;

        emit Approval(msg.sender, spender, amount_);
        return true;
    }

    /**
     * @notice Triggers an approval from owner to spends
     * @param owner The address to approve from
     * @param spender The address to be approved
     * @param amount The number of tokens that are approved (2^256-1 means infinite)
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        uint96 amount_;
        if (amount == uint256(-1)) {
            amount_ = uint96(-1);
        } else {
            amount_ = safe96(
                amount,
                "XMSToken::permit: Amount exceeds 96 bits"
            );
        }
        bytes32 domainSeparator =
            keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes(name)),
                    getChainId(),
                    address(this)
                )
            );

        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            spender,
                            amount,
                            nonce,
                            expiry
                        )
                    )
                )
            );
        address signatory = ecrecover(digest, v, r, s);
        require(signatory == owner, "XMSToken::permit: Unauthorized");
        require(nonce == nonces[owner]++, "XMSToken::permit: Invalid nonce");
        require(signatory != address(0), "XMSToken::permit: Invalid signature");

        require(
            block.timestamp <= expiry,
            "XMSToken::permit: Signature expired"
        );
        _allowances[owner][spender] = amount_;

        emit Approval(owner, spender, amount_);
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return _balances[account];
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `to`
     * @param to The address of the destination account
     * @param rawAmount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address to, uint256 rawAmount)
        external
        override
        returns (bool)
    {
        uint96 amount =
            safe96(rawAmount, "XMSToken::transfer: Amount exceeds 96 bits");
        _transferTokens(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `from` to `to`
     * @param from The address of the source account
     * @param to The address of the destination account
     * @param rawAmount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(
        address from,
        address to,
        uint256 rawAmount
    ) external override returns (bool) {
        address spender = msg.sender;
        uint96 spenderAllowance = _allowances[from][spender];
        uint96 amount =
            safe96(rawAmount, "XMSToken::transferFrom: Amount exceeds 96 bits");

        if (spender != from && spenderAllowance != uint96(-1)) {
            uint96 newAllowance =
                sub96(
                    spenderAllowance,
                    amount,
                    "XMSToken::transferFrom: Transfer amount exceeds spender allowance"
                );
            _allowances[from][spender] = newAllowance;

            emit Approval(from, spender, newAllowance);
        }

        _transferTokens(from, to, amount);
        return true;
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) external override {
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
    ) external override {
        bytes32 domainSeparator =
            keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes(name)),
                    getChainId(),
                    address(this)
                )
            );

        bytes32 structHash =
            keccak256(
                abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)
            );

        bytes32 digest =
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );

        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "XMSToken::delegateBySig: Invalid signature"
        );
        require(
            nonce == nonces[signatory]++,
            "XMSToken::delegateBySig: Invalid nonce"
        );
        require(
            block.timestamp <= expiry,
            "XMSToken::delegateBySig: Signature expired"
        );
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
        override
        returns (uint96)
    {
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
        override
        returns (uint96)
    {
        require(
            blockNumber < block.number,
            "XMSToken::getPriorVotes: Not yet determined"
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

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint96 delegatorBalance = _balances[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _transferTokens(
        address from,
        address to,
        uint96 amount
    ) internal {
        require(
            from != address(0),
            "XMSToken::_transferTokens: Cannot transfer from the zero address"
        );
        require(
            to != address(0),
            "XMSToken::_transferTokens: Cannot transfer to the zero address"
        );

        _balances[from] = sub96(
            _balances[from],
            amount,
            "XMSToken::_transferTokens: Transfer amount exceeds balance"
        );
        _balances[to] = add96(
            _balances[to],
            amount,
            "XMSToken::_transferTokens: Transfer amount overflows"
        );
        emit Transfer(from, to, amount);

        _moveDelegates(delegates[from], delegates[to], amount);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint96 amount
    ) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint96 srcRepOld =
                    srcRepNum > 0
                        ? checkpoints[srcRep][srcRepNum - 1].votes
                        : 0;
                uint96 srcRepNew =
                    sub96(
                        srcRepOld,
                        amount,
                        "XMSToken::_moveDelegates: Vote amount overflows"
                    );
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint96 dstRepOld =
                    dstRepNum > 0
                        ? checkpoints[dstRep][dstRepNum - 1].votes
                        : 0;
                uint96 dstRepNew =
                    add96(
                        dstRepOld,
                        amount,
                        "XMSToken::_moveDelegates: Vote amount overflows"
                    );
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint96 oldVotes,
        uint96 newVotes
    ) internal {
        uint32 blockNumber =
            safe32(
                block.number,
                "XMSToken::_writeCheckpoint: Block number exceeds 32 bits"
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

    function safe96(uint256 n, string memory errorMessage)
        internal
        pure
        returns (uint96)
    {
        require(n < 2**96, errorMessage);
        return uint96(n);
    }

    function add96(
        uint96 a,
        uint96 b,
        string memory errorMessage
    ) internal pure returns (uint96) {
        uint96 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub96(
        uint96 a,
        uint96 b,
        string memory errorMessage
    ) internal pure returns (uint96) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
