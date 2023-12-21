// SPDX-License-Identifier: NONE
pragma solidity 0.8.19;

// Website: https://crvy.wtf/
// Twitter: https://twitter.com/CurveInu
// Telegram: https://t.me/+GHy795RoC7UwOTZh
//
// Welcome to the Dogepound!
// Curvy is a Liquidity Layer accumulator aiming to educate and raise awareness about Curve.
// This is a pure meme coin, so don't expect profits; this project might not succeed.
// We either thrive in the ongoing Curve Wars or perish in the bera market.
// For updates, follow us on Twitter: https://twitter.com/CurveInu
// Visit our website: https://crvy.wtf/
//
// TAX: 6.66%
// - 1.11% tax on both buying and selling for the Helper Treasury
// - 2.22% used to buy CRV (to be held)
// - 3.333% directed to the LP Pool (for compounding over time)
//
// FEATURES:
// - ANTI-SNIPE: Gradually increasing the amount of supply you can purchase per block during the first day of launch
// - UP ONLY: No selling allowed for the first 20 minutes
// - ANTI-SANDWICH: Users can only execute one trade per block
// - FETCH: Users can trigger the fetch function to earn CRVY and contribute to compounding our LP holdings!
//
// TOKENOMICS:
// - 75% of the supply is seeded to LP and locked for 2 years
// - 15% allocated for marketing
// - 10% reserved for exchange listings

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(
        address indexed user, address indexed newOwner
    );

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner)
        public
        virtual
        onlyOwner
    {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(
        address indexed from, address indexed to, uint256 amount
    );

    event Approval(
        address indexed owner, address indexed spender, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount)
        public
        virtual
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        returns (bool)
    {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        returns (bool)
    {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(
            deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED"
        );

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(
                recoveredAddress != address(0)
                    && recoveredAddress == owner,
                "INVALID_SIGNER"
            );

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR()
        public
        view
        virtual
        returns (bytes32)
    {
        return block.chainid == INITIAL_CHAIN_ID
            ? INITIAL_DOMAIN_SEPARATOR
            : computeDomainSeparator();
    }

    function computeDomainSeparator()
        internal
        view
        virtual
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(
                add(freeMemoryPointer, 4),
                and(from, 0xffffffffffffffffffffffffffffffffffffffff)
            ) // Append and mask the "from" argument.
            mstore(
                add(freeMemoryPointer, 36),
                and(to, 0xffffffffffffffffffffffffffffffffffffffff)
            ) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(
                        and(eq(mload(0), 1), gt(returndatasize(), 31)),
                        iszero(returndatasize())
                    ),
                    // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
                )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(ERC20 token, address to, uint256 amount)
        internal
    {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(
                add(freeMemoryPointer, 4),
                and(to, 0xffffffffffffffffffffffffffffffffffffffff)
            ) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(
                        and(eq(mload(0), 1), gt(returndatasize(), 31)),
                        iszero(returndatasize())
                    ),
                    // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
                )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(ERC20 token, address to, uint256 amount)
        internal
    {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0x095ea7b300000000000000000000000000000000000000000000000000000000
            )
            mstore(
                add(freeMemoryPointer, 4),
                and(to, 0xffffffffffffffffffffffffffffffffffffffff)
            ) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(
                        and(eq(mload(0), 1), gt(returndatasize(), 31)),
                        iszero(returndatasize())
                    ),
                    // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
                )
        }

        require(success, "APPROVE_FAILED");
    }
}

interface IFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IRouter {
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

contract Vesting {
    address public immutable token;
    address public immutable to;
    uint256 public immutable timeVested;

    constructor(address _token, address _to, uint256 _timeVested) {
        token = _token;
        to = _to;
        timeVested = _timeVested;
    }

    function pull() external virtual {
        require(block.timestamp >= timeVested, "Vesting: wait");
        ERC20(token).transfer(
            to, ERC20(token).balanceOf(address(this))
        );
    }
}

/// Website: https://CRVY.wtf
/// Twitter: https://twitter.com/CurveInu
/// Telegram: https://t.me/+GHy795RoC7UwOTZh
contract CurveInu is Owned, ERC20("Curve Inu", "CRVY", 18) {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    event Fetch(uint256);
    event FetchCallerFeeSet(uint256);
    event ExcludedSet(address, bool);

    bool public initialized;
    uint256 public fetchCallerFeeBips;
    mapping(address => bool) public isExcluded;
    mapping(address => mapping(uint256 => bool)) public
        isTransferSpent;
    mapping(uint256 => uint256) public transferedOnBlock;

    uint256 internal constant divisorBips = 10_000;
    uint256 public constant liquidityTaxBips = 333;
    uint256 public constant investmentTaxBips = 222;
    uint256 public constant marketingTaxBips = 111;
    uint256 public constant vestingTimeSeconds = 2 * 365 days;
    uint256 public constant totalTaxBips =
        liquidityTaxBips + investmentTaxBips + marketingTaxBips;

    IRouter public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public immutable wrappedEther;
    address public immutable liquidityVesting;
    uint256 public immutable timeSellingAllowed;
    uint256 public immutable timeRemoveAntiSnipe;
    uint256 public immutable timeCreated;

    constructor(
        IFactory factory,
        IRouter router,
        address treasury,
        address weth,
        uint256 supplyToTreasury,
        uint256 supplyToLiquidity,
        uint256 secondsSellingDisabled,
        uint256 secondsAntiSnipeEnabled
    ) Owned(treasury) {
        address pair = factory.createPair(address(this), weth);
        uniswapV2Pair = pair;
        uniswapV2Router = router;
        wrappedEther = weth;
        timeSellingAllowed = block.timestamp + secondsSellingDisabled;
        timeRemoveAntiSnipe =
            block.timestamp + secondsAntiSnipeEnabled;
        timeCreated = block.timestamp;
        uint256 timeVested = block.timestamp + vestingTimeSeconds;
        liquidityVesting =
            address(new Vesting(pair, treasury, timeVested));
        _mint(treasury, supplyToTreasury);
        _mint(address(this), supplyToLiquidity);
        allowance[address(this)][address(uniswapV2Router)] =
            type(uint256).max;
        emit Approval(
            address(this), address(uniswapV2Router), type(uint256).max
        );
        isExcluded[address(treasury)] = true;
        emit ExcludedSet(address(treasury), true);
        isExcluded[address(router)] = true;
        emit ExcludedSet(address(router), true);
        isExcluded[address(this)] = true;
        emit ExcludedSet(address(this), true);
        fetchCallerFeeBips = 500;
        emit FetchCallerFeeSet(500);
    }

    function initialize() external payable virtual onlyOwner {
        require(!initialized);

        uniswapV2Router.addLiquidityETH{value: msg.value}({
            token: address(this),
            amountTokenDesired: balanceOf[address(this)],
            amountTokenMin: 0,
            amountETHMin: 0,
            to: address(liquidityVesting),
            deadline: block.timestamp
        });

        initialized = true;
    }

    function setIsExcluded(address account, bool excluded)
        external
        virtual
        onlyOwner
    {
        isExcluded[account] = excluded;
        emit ExcludedSet(account, excluded);
    }

    function setFetchCallerFee(uint256 fee)
        external
        virtual
        onlyOwner
    {
        require(fee <= 1000, "Curve Inu: fee exceeds 10%");
        fetchCallerFeeBips = fee;
        emit FetchCallerFeeSet(fee);
    }

    function fetch() external virtual {
        uint256 balance = balanceOf[address(this)];
        uint256 fetchFee = balance * fetchCallerFeeBips / divisorBips;
        uint256 balanceMinusFee = balance - fetchFee;
        if (balanceMinusFee != 0) {
            uint256 liquidityTaxHalf = liquidityTaxBips / 2;
            uint256 totalTax = liquidityTaxBips + investmentTaxBips
                + marketingTaxBips;
            uint256 percentToEth =
                divisorBips * (totalTax - liquidityTaxHalf) / totalTax;
            uint256 tokensIn =
                balanceMinusFee * percentToEth / divisorBips;
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = wrappedEther;
            uniswapV2Router.swapExactTokensForETH(
                tokensIn, 0, path, address(this), block.timestamp
            );
            uint256 tokensToLiquidity = balanceMinusFee - tokensIn;
            uint256 etherToLiquidity = address(this).balance
                - address(this).balance
                    * (investmentTaxBips + marketingTaxBips)
                    / (totalTax - liquidityTaxHalf);
            uniswapV2Router.addLiquidityETH{value: etherToLiquidity}({
                token: address(this),
                amountTokenDesired: tokensToLiquidity,
                amountTokenMin: 0,
                amountETHMin: 0,
                to: address(liquidityVesting),
                deadline: block.timestamp
            });
            owner.safeTransferETH(address(this).balance);
            _transferWithTax(address(this), msg.sender, fetchFee);
        }
        emit Fetch(balanceMinusFee);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        return _transferWithTax(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        return _transferWithTax(from, to, amount);
    }

    function _transferWithTax(
        address from,
        address to,
        uint256 amount
    ) internal virtual returns (bool) {
        if (from != address(this) && to == uniswapV2Pair) {
            require(
                block.timestamp >= timeSellingAllowed,
                "Curve Inu: cannot sell yet"
            );
        }

        if (tx.origin == from || tx.origin == to) {
            require(
                !isTransferSpent[tx.origin][block.number],
                "Curve Inu: transfer spent"
            );
            isTransferSpent[tx.origin][block.number] = true;
        }

        uint256 tax;
        if (from.code.length != 0 || to.code.length != 0) {
            if (!isExcluded[from] && !isExcluded[to]) {
                uint256 liquidityTax =
                    amount * liquidityTaxBips / divisorBips;
                uint256 investmentTax =
                    amount * investmentTaxBips / divisorBips;
                uint256 exchangeTax =
                    amount * marketingTaxBips / divisorBips;
                tax = liquidityTax + investmentTax + exchangeTax;

                if (block.timestamp < timeRemoveAntiSnipe) {
                    uint256 newtotalTransfered =
                        transferedOnBlock[block.number] + amount;
                    unchecked {
                        require(
                            newtotalTransfered
                                < maxPurchaseAtTime(block.timestamp),
                            "Curve Inu: anti snipe"
                        );
                    }
                    transferedOnBlock[block.number] =
                        newtotalTransfered;
                }
            }
        }
        balanceOf[from] -= amount;
        unchecked {
            uint256 amountAdjusted = amount - tax;
            balanceOf[to] += amountAdjusted;
            if (tax != 0) {
                balanceOf[address(this)] += tax;
                emit Transfer(from, address(this), tax);
            }
            emit Transfer(from, to, amountAdjusted);
        }
        return true;
    }

    function maxPurchaseAtTime(uint256 time)
        public
        virtual
        returns (uint256)
    {
        uint256 supply = totalSupply;
        if (time > timeRemoveAntiSnipe) return supply;
        return supply * (time - timeCreated)
            / (timeRemoveAntiSnipe - timeCreated);
    }

    receive() external payable virtual {}
}
