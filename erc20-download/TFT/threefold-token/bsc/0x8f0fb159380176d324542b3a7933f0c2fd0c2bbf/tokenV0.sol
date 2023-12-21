pragma solidity >=0.7.0 <0.9.0;

import "./owned_upgradeable_token_storage.sol";

// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

// ----------------------------------------------------------------------------
// ERC20 Token, with the addition of a symbol, name and decimals 
// ----------------------------------------------------------------------------
contract TFT is OwnedUpgradeableTokenStorage {
    using SafeMath for uint;

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    // Lets mint some tokens, also index the TFT tx id
    event Mint(address indexed receiver, uint tokens, string indexed txid);
    // Burn tokens in a withdrawal, user chooses how much tokens
    event Withdraw(address indexed receiver, uint tokens, string blockchain_address, string network);

    // name, symbol and decimals getters are optional per the ERC20 spec. Normally auto generated from public variables
    // but that is obviously not going to work for us

    function name() public view returns (string memory) {
        return getName();
    }

    function symbol() public view returns (string memory) {
        return getSymbol();
    }

    function decimals() public view returns (uint8) {
        return getDecimals();
    }

    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public view returns (uint) {
        return getTotalSupply().sub(getBalance(address(0)));
    }


    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return getBalance(tokenOwner);
    }

    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to `to` account
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transfer(address to, uint tokens) public returns (bool success) {
        setBalance(msg.sender, getBalance(msg.sender).sub(tokens));
        setBalance(to, getBalance(to).add(tokens));
        emit Transfer(msg.sender, to, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    //
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
    // recommends that there are no checks for the approval double-spend attack
    // as this should be implemented in user interfaces 
    // ------------------------------------------------------------------------
    function approve(address spender, uint tokens) public returns (bool success) {
        setAllowed(msg.sender, spender, tokens);
        emit Approval(msg.sender, spender, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    // 
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        setAllowed(from, msg.sender, getAllowed(from, msg.sender).sub(tokens));
        setBalance(from, getBalance(from).sub(tokens));
        setBalance(to, getBalance(to).add(tokens));
        emit Transfer(from, to, tokens);
        return true;
    }

    // -----------------------------------------------------------------------
    // Owner can withdraw and amount of tokens to another network, these tokens will be burned.
    // -----------------------------------------------------------------------
    function withdraw(uint tokens, string memory blockchain_address, string memory network) public returns (bool success) {
        setBalance(msg.sender, getBalance(msg.sender).sub(tokens));
        setTotalSupply(getTotalSupply().sub(tokens));
        emit Withdraw(msg.sender, tokens, blockchain_address, network);
        return true;
    }


    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return getAllowed(tokenOwner, spender);
    }

    // ------------------------------------------------------------------------
    // Don't accept ETH
    // ------------------------------------------------------------------------
    receive() external payable { }

    // -----------------------------------------------------------------------
    // Owner can mint tokens. Although minting tokens to a withdraw address
    // is just an expensive tft transaction, it is possible, so after minting
    // attemt to withdraw.
    // -----------------------------------------------------------------------
    function mintTokens(address receiver, uint tokens, string memory txid) public onlyOwner {
        // check if the txid is already known
        require(!_isMintID(txid), "TFT transacton ID already known");
        _setMintID(txid);
        setBalance(receiver, getBalance(receiver).add(tokens));
        setTotalSupply(getTotalSupply().add(tokens));
        emit Mint(receiver, tokens, txid);
    }

    function isMintID(string memory _txid) public view returns (bool) {
        return _isMintID(_txid);
    }

    function _setMintID(string memory _txid) internal {
        setBool(keccak256(abi.encode("mint","transaction","id",_txid)), true);
    }

    function _isMintID(string memory _txid) internal view returns (bool) {
        return getBool(keccak256(abi.encode("mint","transaction","id", _txid)));
    }
}