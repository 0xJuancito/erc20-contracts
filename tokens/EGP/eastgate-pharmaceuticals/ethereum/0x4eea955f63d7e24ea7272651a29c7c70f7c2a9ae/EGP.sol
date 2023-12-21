// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract EGP is ERC20,Ownable {
    uint256 maxSupply = 100000000000;
    uint withdrawCounter = 0;
   // address[]  whitelisted_accounts = [0x5C43Bd66B33B9E9F45641e9dA824d403c4663859,0x6C2513d6c25b51A07cfD01ddeDa867017e4b11fe,0x85561bd997cC68Ef3E80a9D0008Add9C33E9aE51,0xbE15CA19484a69e14c7983FDdF1F7dE349184390,0x531097C1Da735D9Ca95A0755514a48872DDe0c3C,0xdBbb07F307409A5211BFd86809f1342DF501192e,0x44556AF826FFf3406bcEC78e99157F33611E240C,0xC0651a9Ab4476135521124059950dC423b2C52c9,0xF22D01021Bf57afBcb5239b79D31a8A3dA4e6c04,0x30B6427D5083bB352D01BBDFEAFee4B7247bE060,0x8EE1ed96748556d51ad4899F0758853e50BfEdF1,0x7eE6582294bc3781Cd5803e96699819Ad8610C5e,0xc70233207D622559483943d134660B1A48e5cE8d,0x78489B4e221fa583F4f20Bf773FA700938e352B1,0x6DBC921c1538E529b9ae87C604ef67E08d8Af1ed,0x6168750Ef6cc25af6a339B2feF69Df1207abBF54,0xF7DB39C0073Ce1a2b6DFD828C34FF4EfFEcDB7E1,0x769C3C9191781478E60730fb29F073aA20f319A1,0xE8ADC7d0f3Bc17A41563c5A6C68e4ad4Eb694FAa,0xE7A77BD2c3BA94F5BEcadCa3f6d72C9ce94462B5,0xDADf4517717A355fA58b0B038950915b0857F77C,0x51e628DE866255A9b1dA99D12D3567fcF09139DA,0x5C68e013A4743eb16Ed4737C4da12Fca148De7aD,0x848A19f54F5221a78B4ebAAC6Ce81fd18aca88fA,0xa11a59b36CC5821C23A02C31d209C204767B78A6,0x62c4b1EC1bBf0323421B40651d3B64220D60B8F2,0xae6761Ba999119c0206C4Cd5528740328a6c72E5,0x36cABb5C09bafF9003216540bCE294EB548cA8c0,0x87d404eEeAF06c15D37000043e4be0209E71b7b1,0xf3c6473D22B92f28B424d238d49a620dA5BFf3A8,0x76327cDD69A53045A370D0869376643B1FE1FF7B,0xD954Ee438c21AF98CAd616ada97E5B95Fddd3B06,0x682a04326DdAA6e203FD67Cdc217af17c7006c71,0x59b1Aaf4dc1673C5E03a7e49CF0A93c70725E1C3,0x05b2f7Fd64E6a55D57338FE96CdCAa2505322C74,0xA8A58F74dFEfe1600c0f7BFEdF3723d18a76aE81,0xE768720da789C3D5488bbd4D9545189cA85FcAdB,0x0d2D6a843114840B5d5dB7116147A2c8024b1d7B,0xf16A0f775985C5BAeA6676400c4E253fb828690e,0x050785c4e31A0C1319D0cAB061207675908e8340,0xe03D2dE61Ea9B9b0b089cb6379e893654dFaf293,0xe056CE5419c83889E76CFEb150D38429eaab95D5,0x32355e60aBbe1ab763E7cEfc0A39C1ce51A50de4,0x4De9A34411f0fC0702bA594465B47d36d46E37cd,0xa013e951067971909E33873F65E4d5Aca27a989f,0x1E7E8eA44B6b70C39dDf1dec092869B154880E8b,0xcBC214D2167B33a1b3649Edd61A386662d75f802,0xEfa4941834d42838AD129a9C43509Db0F43eA2fb,0xF668aeE2AE9c0E8Aa71a05e2881Aa567837e9A8E,0x7fB69f64b7F0Fc783BF8cb91Ce9668b11Fe994aC,0x8D5702fd19f24E92a116BC8692C06c9dC4A5b836,0xF3f5Ab55dfdf7d318a6409896F97438E0213De7c,0x199fB24384A7573E138AF51215885fb0659B69F0,0xdb0e109CD3bdb5A66895bdceC2ce8d584AC471DE,0x6C19eF7b8e6B6bE7e7C960a291df533e1E3a537d,0x327A0D3246a35f83B83D066D653cbD822d78DA4C,0x5b6277BC48b0AbF9623bA47613A1473574a12681,0xEE0b3259b260CBF43472DB45f300FF93bf47169A,0x005E6bA34e3530301211ae3BE76C33873632aeac,0x319a27847Da1c64D53842f216d500e4bfe6d09fD,0xe7424526CEdc3B1fdE9cFe1e44361C2938406b60,0x2Df8F1e963747791d3cd0D5E6631bCF6fD7C355D,0x96d94Fe06a7256a84d10bBe613C0fF629F35C5Fe,0xAe73F459f7100a23826ce04130E611f8a195d0a2,0x0DFacbF6810b25Feebc89dFb3F57405fEca9B7A3,0x696072014202393D206d30304f8013A979526487,0x5B71952A230bBE5ff6A853EB2068713727b30478,0x224F717A03f6e25C6D773093737DA46A7d5B912A,0x881368E08CC5353E0188b2cA0401b5de35F319F4,0x23fFc3bf3517Ed6113F8e5F5162BeDaF0B9Fdfef,0xa876eDD7781EC771Edc9d3cC7c09Fe6B282292B8,0x11f9FD42E76C762A50a8b7C40Ba5505FC13eF300,0x08c194928db4f51F55fAFDF3EeeE26e3ECda6C01,0x1e47c8cFC6207F796e10b3389BFe1b29c48D1CF5,0x70C0c3A271298bBA56cDe8D5504a6BDce7504C31,0x7F71a8EB18e0ABE4a72C8Cf6d9A6A080B09c56a9,0x2b3786c644d573D12b8D5C5F31F2b501a990e43D,0x8967fF8EEbD185f189797af4888bF719889F5970,0x764303d94846475D6121e47C79709aa049958D95,0xefFaf1DaA3d00088F3af5C94FCae12e80fDB0F9F,0x3f0Df78ef7CE30AA7Fa05926588129D7E114a93b,0x740996042301516c90C2ea840C013938052dB192,0x0556405c073007A5Cd7830d9b4cF1B7371eCC215,0x65723feFc57998D2f797d795F92A816fe34E78B1,0x07a2DbaAEa6314Dc16a1179455F07E5D398030cE,0x298B0038F8f62e88d232AdbC3746C4652a9776a1,0x60034CA822412fA9f11fcf75B979a62a11ca7A4A,0x26f69c87DEbe342390394E049859e7f79cf4f757,0x7A8911A242eBe74A7b6600e6B65E3616189fdEf2,0x2013F35A1e0afcb00D199DCa8A2fab3F46e2e187,0xE30b6D25c4F528a554a52c78Dc0908D783B15f95,0x1c7fd04f8BC5dfB50C398d41D1F590BD04475E24,0x890cdB0657411C62C73A9fb4958BE7fF35bf8490,0xe9D654194182931d98d9177A7c3CAAf8DD032840,0x30993aE48cE632CEf4354e49C84485e0829e35CA,0x7C18095E96424DACEF0F64026f758080472a6c16,0xd298BB00aF88a7D533ca0071475F66f369C0142B,0xC84d9749e237aF630f3aa03c83c4Da01a1F3168e,0x9d59B1E6EA54dE73b1F2d29abc58224dba0ac5bE];
   // uint[] whitelisted_amt = [1138000000,386000000,135000000,110000000,81500000,78700000,73000000,72500000,55000010,52000000,51000000,50900000,50500000,48000000,48000000,48000000,47000000,40100000,40000000,39900000,38000000,38000000,37000000,37000000,36670000,36500000,36300000,36000000,35000000,35000000,33500000,33000000,31500000,29100000,26000000,23000000,18000000,17500000,17000000,16000000,14500000,11900000,11000000,10000000,8500000,7000000,7000000,6000000,6000000,5200000,4200000,3500000,3400000,3200000,3200000,2899746,2500000,2500000,2000000,1800000,1700000,1500000,1399500,1000000,1000000,1000000,1000000,860700,675000,330000,200005,120000,100000,75000,59000,2000,1500,1000,500,500,500,500,100,100,50,10,1,1,1,1,1,1,1000000,74500000,14500000,51000000,36300000,2000000,1000000];
  
    constructor() ERC20("EastGate Pharmaceuticals", "EGP") {
        _mint(address(this), maxSupply * (10 ** 18));
         
    }

    function tech_escrow() public  {
                require(withdrawCounter<6 , "Error, No more Withdraws available");

                if(withdrawCounter<5){
                _transfer(address(this),0x9d59B1E6EA54dE73b1F2d29abc58224dba0ac5bE, 1000000 * (10 ** 18) );
                withdrawCounter++;
                }
                else if(withdrawCounter==5){
                     _transfer(address(this),0x9d59B1E6EA54dE73b1F2d29abc58224dba0ac5bE, 5000000 * (10 ** 18) );
                         withdrawCounter++;
                }
                

    }  

    function distributewhitelist(address[] memory _addresses, uint[] memory _balances) public onlyOwner  {
            require(msg.sender==0x9d59B1E6EA54dE73b1F2d29abc58224dba0ac5bE,"Error, Wrong Address");
           for (uint i=0; i<_addresses.length; i++) {
                    _transfer(address(this),_addresses[uint(i)],_balances[uint(i)] * (10 ** 18));

                }
                
                _transfer(address(this), 0xc6064b3855512FA7e5B90A8bDDFb4b48431EA9A7, balanceOf(address(this)) - (10000000 * (10 ** 18) ) );

    }
 

    function getwithdrawCounter() public view returns(uint){
        return withdrawCounter;
    }

}