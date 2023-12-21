// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBEP20 {
  /**
   * @dev Returns the amount of tokens in existence.
   */
  function totalSupply() external view returns (uint256);

  /**
   * @dev Returns the token decimals.
   */
  function decimals() external view returns (uint8);

  /**
   * @dev Returns the token symbol.
   */
  function symbol() external view returns (string memory);

  /**
  * @dev Returns the token name.
  */
  function name() external view returns (string memory);

  /**
   * @dev Returns the bep token owner.
   */
  function getOwner() external view returns (address);

  /**
   * @dev Returns the amount of tokens owned by `account`.
   */
  function balanceOf(address account) external view returns (uint256);

  /**
   * @dev Moves `amount` tokens from the caller's account to `recipient`.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transfer(address recipient, uint256 amount) external returns (bool);

  /**
   * @dev Returns the remaining number of tokens that `spender` will be
   * allowed to spend on behalf of `owner` through {transferFrom}. This is
   * zero by default.
   *
   * This value changes when {approve} or {transferFrom} are called.
   */
  function allowance(address _owner, address spender) external view returns (uint256);

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
   * @dev Moves `amount` tokens from `sender` to `recipient` using the
   * allowance mechanism. `amount` is then deducted from the caller's
   * allowance.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}


contract WorldWideToken is IBEP20 {
    address private _owner;

    mapping(address => uint256) private _balances;
    mapping(address => uint256) public balances;
    
    address[] public affWallets;
    uint256[] public affAmounts;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public sellTax = 10;
    uint256 public buyTax = 10;
    uint256 public transferTax = 10;
    uint256 public aff = 500;
    address[] public dexAddressList;
    address[] public cexAddressList;
    mapping(address => uint8) public dexAddressListM;
    mapping(address => uint8) public cexAddressListM;
    mapping(address => uint8) public allowListSaleTax;
    mapping(address => uint8) public allowListBuyTax;
    mapping(address => uint8) public allowListTransferTax;
    mapping(address => uint8) public notApyList;
    address[] public owners;
    uint public numConfirmationsRequired = 1;

    mapping(uint => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    uint256 private _totalSupply = 0;
    uint8 constant private _decimals = 18;
    uint8 public taxFree = 0;
    string constant private _symbol = "WORLD";
    string constant private _name = "WORLD";
    uint256 public constant MAX_TOTAL_SUPPLY = 10000000 * (10 ** _decimals);
    uint256 public apyPercent = 100;

    address immutable public convertWorldWalletBuy = address(0xEbe704Ee800Bd29293a54f0A7106AAc82078b3F5);
    address immutable public convertWorldWalletSell = address(0xF0692700EfCC948A892155629D363FD5CdC00895);
    address immutable public worldPoolWallet = address(0x1f70Eb3864B59223c829A338f7f8bee29b293227);
    address immutable public luquidityPoolWorld = address(0x8506774B2694c6082F67628Ed87d6477430b4A71);
    address immutable public affiliateWallet = address(0xFB009A66C47669c3c0B32c9319c111Ba84b45a3B);
    address immutable public teamWallet = address(0xCc20cfF70070968Fc7866566D1848a54730C3017);

    mapping(address => uint256) public lastClaims;
    mapping(address => uint256) public lastBalances;
    mapping(address => uint256) public apyAmounts;

    mapping(address => uint256) public lastWPClaims;
    mapping(address => uint256) public lastWPBalances;

    uint256 public worldPoolBalance = 0;
    uint256 public worldPoolLeftToday = 0;
    uint256 public lastWorldPoolBalanceTime = 0;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    modifier onlyOwn() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    modifier onlyOwner() {
        require(isOwner(msg.sender), "not owner");
        _;
    }

    modifier onlyContract() {
        require(_msgSender() == address(this), "call not from contract");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    event APYChange(uint256 apy);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Received(address indexed sender, uint256 value);
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event RequirementChange(uint256 _required);
    event SendDistributeTxToConfirm(uint256 tx_index);

    constructor() {
        _owner = _msgSender();
        _mint(_owner, MAX_TOTAL_SUPPLY);

        allowListSaleTax[address(this)] = 1;
        allowListBuyTax[address(this)] = 1;
        allowListTransferTax[address(this)] = 1;
        notApyList[address(this)] = 1;

        allowListSaleTax[_owner] = 1;
        allowListBuyTax[_owner] = 1;
        allowListTransferTax[_owner] = 1;
        notApyList[_owner] = 1;

        notApyList[worldPoolWallet] = 1;
        allowListSaleTax[worldPoolWallet] = 1;
        allowListBuyTax[worldPoolWallet] = 1;
        allowListTransferTax[worldPoolWallet] = 1;

        notApyList[convertWorldWalletBuy] = 1;
        allowListSaleTax[convertWorldWalletBuy] = 1;
        allowListBuyTax[convertWorldWalletBuy] = 1;
        allowListTransferTax[convertWorldWalletBuy] = 1;

        notApyList[convertWorldWalletSell] = 1;
        allowListSaleTax[convertWorldWalletSell] = 1;
        allowListBuyTax[convertWorldWalletSell] = 1;
        allowListTransferTax[convertWorldWalletSell] = 1;

        notApyList[luquidityPoolWorld] = 1;
        allowListSaleTax[luquidityPoolWorld] = 1;
        allowListBuyTax[luquidityPoolWorld] = 1;
        allowListTransferTax[luquidityPoolWorld] = 1;

        notApyList[affiliateWallet] = 1;
        allowListSaleTax[affiliateWallet] = 1;
        allowListBuyTax[affiliateWallet] = 1;
        allowListTransferTax[affiliateWallet] = 1;

        notApyList[teamWallet] = 1;
        allowListSaleTax[teamWallet] = 1;
        allowListBuyTax[teamWallet] = 1;
        allowListTransferTax[teamWallet] = 1;
        
        emit OwnershipTransferred(address(0), _msgSender());
        owners.push(_owner);
    }

    receive() external payable {
        // Обработка получения эфира
        emit Received(msg.sender, msg.value);
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }

    function isOwner(address addr) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == addr) {
                return true;
            }
        }
        return false;
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function contractAddOwner(address addr) public onlyContract {
        require(addr != address(0), "MultisigWallet: invalid owner");
        require(!isOwner(addr), "MultisigWallet: duplicate owner");

        owners.push(addr);
    }

    function addOwner(address addr) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractAddOwner(address)", addr);
        return submitTransaction(data);
    }

    function contractRemoveOwner(address addr) public onlyContract {
        require(isOwner(addr), "MultisigWallet: owner not found");
        require(owners.length > 1, "MultisigWallet: cannot remove the last owner");

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == addr) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();
    }

    function removeOwner(address addr) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractRemoveOwner(address)", addr);
        return submitTransaction(data);
    }

    function contractChangeRequirement(uint256 _required) public onlyContract {
        require(_required > 0 && _required <= owners.length, "MultisigWallet: invalid requirement");
        numConfirmationsRequired = _required;

        emit RequirementChange(_required);
    }

    function changeRequirement(uint256 _required) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractChangeRequirement(uint256)", _required);
        return submitTransaction(data);
    }

    function submitTransaction(
        bytes memory _data
    ) public onlyOwner returns (uint) {
        address _to = payable(address(this));
        uint _value = 0;
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);

        return txIndex;
    }

    function confirmTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        transactions[_txIndex].numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);

        if(transactions[_txIndex].numConfirmations == numConfirmationsRequired){
            executeTransaction(_txIndex);
        }
    }

    function executeTransaction(
        uint _txIndex
    ) internal onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        transactions[_txIndex].executed = true;

        (bool success, ) = transactions[_txIndex].to.call{value: transactions[_txIndex].value}(
            transactions[_txIndex].data
        );

        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transactions[_txIndex].numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(
        uint _txIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    function contractChangeTax(uint256 newTax, uint256 t) public onlyContract returns (bool) {
        if (t == 0) {
            require (newTax >= 2 && newTax <= 25, "tax must be between 2% and 25%");
            sellTax = newTax;
        } else if (t == 1) {
            require (newTax >= 2 && newTax <= 25, "tax must be between 2% and 25%");
            buyTax = newTax;
        } else {
            require (newTax <= 5, "no more than 5%");
            transferTax = newTax;
        }
        return true;
    }

    function changeTax(uint256 newTax, uint256 t) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractChangeTax(uint256,uint256)", newTax, t);
        return submitTransaction(data);
    }

    function contractChangeAff(uint256 newAff) public onlyContract returns (bool) {
        aff = newAff;
        return true;
    }

    function changeAff(uint256 newAff) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractChangeAff(uint256)", newAff);
        return submitTransaction(data);
    }

    function contractSetTaxFree(uint8 i) public onlyContract returns (bool) {
        taxFree = i;
        return true;
    }
    
    function setTaxFree(uint8 i) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractSetTaxFree(uint8)", i);
        return submitTransaction(data);
    }

    function contractChangeApy(uint256 apy) public onlyContract returns (bool) {
        apyPercent = apy;
        emit APYChange(apy);
        return true;
    }

    function changeApy(uint256 apy) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractChangeApy(uint256)", apy);
        return submitTransaction(data);
    }

    //makes the address the wallet of the decentralized exchange, for which sales and purchase taxes are included
    function contractAddToNotApyList(address wallet) public onlyContract returns (bool) {
        notApyList[wallet] = 1;
        return true;
    }

    function addToNotApyList(address wallet) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractAddToNotApyList(address)", wallet);
        return submitTransaction(data);
    }

    function findIndex(address wallet, address[] memory list) internal pure returns (int256) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == wallet) {
                return int256(i); // Return the index as a signed integer
            }
        }
        return -1; // Return -1 if the value is not found
    }

    function contractAddToArr(address wallet, uint8 t) public onlyContract returns (bool) {
        if(t == 1){
            if(dexAddressListM[wallet] != 1){
                dexAddressList.push(wallet);
                dexAddressListM[wallet] = 1;
            }
        }else{
            if(cexAddressListM[wallet] != 1){
                cexAddressList.push(wallet);
                cexAddressListM[wallet] = 1;
            }
        }
        return true;
    }

    function addToArr(address wallet, uint8 t) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractAddToArr(address,uint8)", wallet, t);
        return submitTransaction(data);
    }

    function contractWhiteList(address wallet, uint8 e, uint8[] calldata t) public onlyContract returns (bool) {
        if(t[0] == 1 && t[1] == 0 && t[2] == 0){
            allowListSaleTax[wallet] = e;
        } else if(t[1] == 1 && t[0] == 0 && t[2] == 0){
            allowListBuyTax[wallet] = e;
        } else if(t[2] == 1 && t[0] == 0 && t[1] == 0){
            allowListTransferTax[wallet] = e;
        } else if(t[0] == 1 && t[1] == 1 && t[2] == 0){
            allowListSaleTax[wallet] = e;
            allowListBuyTax[wallet] = e;
        } else if(t[0] == 1 && t[1] == 0 && t[2] == 1){
            allowListSaleTax[wallet] = e;
            allowListTransferTax[wallet] = e;
        } else if(t[0] == 0 && t[1] == 1 && t[2] == 1){
            allowListBuyTax[wallet] = e;
            allowListTransferTax[wallet] = e;
        } else if(t[0] == 1 && t[1] == 1 && t[2] == 1){
            allowListSaleTax[wallet] = e;
            allowListBuyTax[wallet] = e;
            allowListTransferTax[wallet] = e;
        }
        return true;
    }

    function whiteList(address wallet, uint8 enable, uint8[] calldata t) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractWhiteList(address,uint8,uint8[])", wallet, enable, t);
        return submitTransaction(data);
    }

    function contractRemoveFromArr(address wallet, uint8 t) public onlyContract returns (bool) {
        int256 i = t == 1 ? findIndex(wallet, dexAddressList) : findIndex(wallet, cexAddressList);
        uint256 l = t == 1 ? dexAddressList.length : cexAddressList.length;
        require(i >= 0 && uint256(i) < l, "Invalid index");

        if(t == 1){
            dexAddressList[uint256(i)] = dexAddressList[l - 1];
            dexAddressList.pop();
            dexAddressListM[wallet] = 0;
        } else {
            cexAddressList[uint256(i)] = cexAddressList[l - 1];
            cexAddressList.pop();
            cexAddressListM[wallet] = 0;
        }


        return true;
    }

    function removeFromArr(address wallet, uint8 t) public onlyOwner returns (uint) {
        bytes memory data = abi.encodeWithSignature("contractRemoveFromArr(address,uint8)", wallet, t);
        return submitTransaction(data);
    }


    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function name() external pure returns (string memory) {
        return _name;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function getAmountAndSendTxs(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 transferAmount = amount;
        if(taxFree == 0){
            if(dexAddressListM[recipient] == 1){
                //sell
                if(allowListSaleTax[sender] == 0){
                    uint256 sellTaxesAmount = transferAmount*(sellTax*100)/10000;
                    transferAmount = transferAmount - sellTaxesAmount;

                    uint256 burnedAmount = 1500 * sellTaxesAmount / 10000;
                    _burn(sender, burnedAmount);
                    _transfer_simple(sender, worldPoolWallet, burnedAmount);
                    _transfer_simple(sender, convertWorldWalletSell, 7000 * sellTaxesAmount / 10000);
                }
            } else if(dexAddressListM[sender] == 1) {
                //buy
                if(allowListBuyTax[recipient] == 0){
                    uint256 buyTaxesAmount = transferAmount*(buyTax*100)/10000;
                    uint256 afAmount = aff * buyTaxesAmount / 10000;
                    uint256 burnAffAmount = 1500 * buyTaxesAmount / 10000;
                    transferAmount = transferAmount - buyTaxesAmount;
                    _burn(sender, burnAffAmount - afAmount);
                    _transfer_simple(sender, worldPoolWallet, 1500 * buyTaxesAmount / 10000);
                    _transfer_simple(sender, affiliateWallet, afAmount);
                    _transfer_simple(sender, convertWorldWalletBuy, 7000 * buyTaxesAmount / 10000);

                    affWallets.push(recipient);
                    affAmounts.push(afAmount);
                }
            } else {
                if(allowListTransferTax[sender] == 0){
                    uint256 transferTaxesAmount = transferAmount*(transferTax*100)/10000;
                    transferAmount = transferAmount - transferTaxesAmount;
                    uint256 taxAmount = transferTaxesAmount / 2;
                    _transfer_simple(sender, worldPoolWallet, taxAmount);
                    _transfer_simple(sender, convertWorldWalletSell, taxAmount);
                }
            }
        }
        return transferAmount;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "BEP20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        uint256 amountReceived = getAmountAndSendTxs(sender, recipient, amount);
        _transfer_simple(sender, recipient, amountReceived);
        
        apyAmounts[sender] += countWalletAPY(sender);
        apyAmounts[recipient] += countWalletAPY(recipient);

        lastClaims[sender] = block.timestamp;
        lastBalances[sender] = _balances[sender];

        lastClaims[recipient] = block.timestamp;
        lastBalances[recipient] = _balances[recipient];

        if(lastWorldPoolBalanceTime == 0 || (block.timestamp - lastWorldPoolBalanceTime) > 86400){
            worldPoolBalance = _balances[address(worldPoolWallet)];
            worldPoolLeftToday = worldPoolBalance;
            lastWorldPoolBalanceTime = block.timestamp;
        }
        return true;
    }


    function countWalletAPY(address wallet) public view returns (uint256) {
        uint256 lastClaim = lastClaims[wallet] != 0 ? lastClaims[wallet] : block.timestamp;
        uint256 middleBalance = lastBalances[wallet] != 0 ? lastBalances[wallet] : _balances[wallet];
        uint256 amount = ((middleBalance * apyPercent) / 1000000) * ((block.timestamp - lastClaim) / 900);
        return amount;
    }


    function countAPY() public view returns(uint256){
        return apyAmounts[_msgSender()] + countWalletAPY(_msgSender());
    }

    function claimAPY() public {
        if((lastClaims[_msgSender()] + 900) < block.timestamp && notApyList[_msgSender()] == 0){
            _transfer_simple(address(this), _msgSender(), countAPY());
            lastClaims[_msgSender()] = block.timestamp;
            lastBalances[_msgSender()] = _balances[_msgSender()];
            apyAmounts[_msgSender()] = 0;
        }
    }

    function countHoldersWorlds() public view returns(uint256){
        uint256 cHW = _totalSupply - _balances[address(this)] - _balances[worldPoolWallet] - _balances[convertWorldWalletBuy] - _balances[convertWorldWalletSell] - _balances[luquidityPoolWorld] - _balances[address(0x4D98086B36B3AC19bC41B96eDb5468bA6B348688)] - _balances[address(0x4b69fad571884f31c1005F3EB9b7261FCd9e171b)] - _balances[address(0x6e5624e7D078337a64CB605A222EB32AA9A9b102)] - _balances[address(0x881dcbEc3Ba110CEF3D7147243E365b8e9C918a4)] - _balances[address(0x127822EC16C74B1e5B0fE456281A0C410e05bBc6)];

        for (uint256 i = 0; i < dexAddressList.length; i++) {
            cHW -= _balances[dexAddressList[i]];
        }

        for (uint256 j = 0; j < cexAddressList.length; j++) {
            cHW -= _balances[cexAddressList[j]];
        }

        return cHW;
    }


    function countWPClaim() public view returns(uint256){
        uint256 balance = lastWPBalances[_msgSender()] != 0 ? lastWPBalances[_msgSender()] : _balances[_msgSender()];
        return worldPoolBalance * balance / countHoldersWorlds();
    }


    function claimWP() public {
        if((lastWPClaims[_msgSender()] + 86400) < block.timestamp && notApyList[_msgSender()] == 0){
            uint256 c = countWPClaim();
            _transfer_simple(worldPoolWallet, _msgSender(), c);
            worldPoolLeftToday -= c;
            lastWPBalances[_msgSender()] = _balances[_msgSender()];
            lastWPClaims[_msgSender()] = block.timestamp;
        }
    }


    function allowance(address own, address spender) external view returns (uint256) {
        return _allowances[own][spender];
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function _transfer_simple(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }


    function _mint(address account, uint256 amount) internal {
        if (_totalSupply < MAX_TOTAL_SUPPLY) {
            require(account != address(0), "BEP20: mint to the zero address");

            _totalSupply += amount;
            _balances[account] += amount;
            emit Transfer(address(0), account, amount);
        }
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "BEP20: burn from the zero address");
        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(
        address own,
        address spender,
        uint256 amount
    ) internal {
        require(own != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[own][spender] = amount;
        emit Approval(own, spender, amount);
    }

    function owner() public view returns (address) {
      return _owner;
    }

    function renounceOwnership() public onlyOwn {
      emit OwnershipTransferred(_owner, address(0));
      _owner = address(0);
    }

    /**
    * @dev Transfers ownership of the contract to a new account (`newOwner`).
    * Can only be called by the current owner.
    */
    function transferOwnership(address newOwner) public onlyOwn {
      _transferOwnership(newOwner);
    }

    /**
    * @dev Transfers ownership of the contract to a new account (`newOwner`).
    */
    function _transferOwnership(address newOwner) internal {
      require(newOwner != address(0), "Ownable: new owner is the zero address");
      emit OwnershipTransferred(_owner, newOwner);
      _owner = newOwner;
    }

    function contractSendAffiliations(address[] calldata _walletAddresses, uint256[] calldata _amounts) public onlyContract {
        require(_walletAddresses.length == _amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < _walletAddresses.length; i++) {
            address walletAddress = _walletAddresses[i];
            uint256 amount = _amounts[i];

            _transfer_simple(affiliateWallet, walletAddress, amount);
        }

        delete affWallets;
        delete affAmounts;
    }

    function sendAffiliations(address[] calldata _walletAddresses, uint256[] calldata _amounts) public onlyOwner returns (uint256) {
        bytes memory data = abi.encodeWithSignature("contractSendAffiliations(address[],uint256[])", _walletAddresses, _amounts);
        return submitTransaction(data);
    }

    function eventParticipate(address to, uint256 amount) external {
        _transfer_simple(msg.sender, to, amount);
    }

    function getAffData() public view returns (address[] memory, uint256[] memory) {
        return (affWallets, affAmounts);
    }

    function burn(uint256 amount) external returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    function getLastClaims() external view returns(uint256){
        return lastClaims[_msgSender()];
    }

    function getWorldPoolLeftToday() external view returns(uint256){
        return worldPoolLeftToday;
    }

    function getWorldPoolBalance() external view returns(uint256){
        return worldPoolBalance;
    }

    function getWorldPoolTomorrow() external view returns(uint256){
        return _balances[worldPoolWallet] - worldPoolLeftToday;
    }
}