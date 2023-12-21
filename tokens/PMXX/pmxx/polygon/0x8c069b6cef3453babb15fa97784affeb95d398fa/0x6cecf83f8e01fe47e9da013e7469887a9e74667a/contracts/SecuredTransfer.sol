// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct transactionInfo { 
    address to;
    address from;
    uint256 amount;
    bytes32 claimHash;
}

contract SecuredTransfer is Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // MBMX token
    IERC20Upgradeable token;
    

    // hash transaction info mapping
    mapping (bytes32 => transactionInfo) public hashTransactionInfo;

    // user reveive transactions
    mapping (address => EnumerableSet.Bytes32Set) received;
    
    // user sent transactions
    mapping (address => EnumerableSet.Bytes32Set) sent;

    /**
     * @dev constructor of SafeTransfer
     * @param token_ address of MBMX token
    */
    constructor (address token_) {
        token = IERC20Upgradeable(token_);
    }

    /**
     * @dev sending coins safe on to address
     * @param to receiver address
     * @param from sender address
     * @param amount amount of coins
     * @param msgHash hash of message
    */
    function sendSecured(address to, address from, uint256 amount, bytes32 msgHash) external onlyOwner {
        hashTransactionInfo[msgHash] = transactionInfo(to, from, amount, msgHash);
        received[to].add(msgHash);
        sent[from].add(msgHash);
    }

    /**
     * @dev checking parameters if it's valid hash
     * @param from sender address
     * @param to receiver address
     * @param amount amount of coins
     * @param code secret code
    */
    modifier validateHash(address from, address to, uint256 amount, uint256 code) {
        bytes32 messageHash = keccak256(abi.encodePacked(to, from, amount, code)); 
        require(hashTransactionInfo[messageHash].to != address(0), "SafeTransfer: invalid hash");
        delete hashTransactionInfo[messageHash];
        received[to].remove(messageHash);
        sent[from].remove(messageHash);
        _;
    }

    /**
     * @dev claiming coins
     * @param from sender address
     * @param to receiver address
     * @param amount amount of coins
     * @param code secret code
    */
    function claim(address from, address to, uint256 amount, uint256 code) 
    external 
    onlyOwner
    validateHash(from, to, amount, code)
    {
        token.transfer(to, amount);
    }

    /**
     * @dev get users received transfers
     * @param to receiver address
    */
    function getUserClaimTransfers(address to) external onlyOwner view returns (transactionInfo[] memory)
    {
        EnumerableSet.Bytes32Set storage receivedMap = received[to];
        transactionInfo[] memory receivedArray = new transactionInfo[](receivedMap.length());

        for (uint256 k = 0; k < receivedArray.length; ++ k) {
            bytes32 msgHash = receivedMap.at(k);
            receivedArray[k] = hashTransactionInfo[msgHash];
        }

        return receivedArray;
    }
    
    /**
     * @dev get user's sent transfers
     * @param from sender address
    */
    function getUserSentTransfers(address from) external onlyOwner view returns (transactionInfo[] memory) {
        EnumerableSet.Bytes32Set storage sentMap = sent[from];
        transactionInfo[] memory sentArray = new transactionInfo[](sentMap.length());

        for (uint256 k = 0; k < sentArray.length; ++ k) {
            bytes32 msgHash = sentMap.at(k);
            sentArray[k] = hashTransactionInfo[msgHash];
        }

        return sentArray;
    }

    /**
     * @dev revoke safe transfer transaction
     * @param from sender address
     * @param msgHash hash of transfer
    */
    function revertTransfer(address from, bytes32 msgHash) 
    external
    onlyOwner 
    {
        transactionInfo memory info = hashTransactionInfo[msgHash];
        require(info.from == from, "SafeTransfer: invalid hash");
        received[info.to].remove(msgHash);
        sent[info.from].remove(msgHash);
        delete hashTransactionInfo[msgHash];
        token.transfer(from, info.amount);    
    }
}
