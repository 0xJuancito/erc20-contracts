pragma solidity ^0.5.8;

import "./IMaster.sol";
import "./IERC20.sol";

/**
 * Provides functionality of relay contract
 */
contract Relay {
    bool internal initialized_;
    address payable private masterAddress;
    IMaster private masterInstance;

    event AddressEvent(address input);
    event StringEvent(string input);
    event BytesEvent(bytes32 input);
    event NumberEvent(uint256 input);

    /**
     * Relay constructor
     * @param master address of master contract
     */
    constructor(address payable master) public {
        initialize(master);
    }

    /**
     * Initialization of smart contract.
     */
    function initialize(address payable master) public {
        require(!initialized_);
        masterAddress = master;
        masterInstance = IMaster(masterAddress);
        initialized_ = true;
    }

    /**
     * A special function-like stub to allow ether accepting
     */
    function() external payable {
        require(msg.data.length == 0);
        emit AddressEvent(msg.sender);
    }

    /**
     * Sends ether and all tokens from this contract to master
     * @param tokenAddress address of sending token (0 for Ether)
     */
    function sendToMaster(address tokenAddress) public {
        // trusted call
        require(masterInstance.checkTokenAddress(tokenAddress));
        if (tokenAddress == address(0)) {
            // trusted transfer
            masterAddress.transfer(address(this).balance);
        } else {
            IERC20 ic = IERC20(tokenAddress);
            // untrusted call in general but coin addresses are received from trusted master contract
            // which contains and manages whitelist of them
            ic.transfer(masterAddress, ic.balanceOf(address(this)));
        }
    }

    /**
     * Withdraws specified amount of ether or one of ERC-20 tokens to provided address
     * @param tokenAddress address of token to withdraw (0 for ether)
     * @param amount amount of tokens or ether to withdraw
     * @param to target account address
     * @param tx_hash hash of transaction from Iroha
     * @param v array of signatures of tx_hash (v-component)
     * @param r array of signatures of tx_hash (r-component)
     * @param s array of signatures of tx_hash (s-component)
     * @param from relay contract address
     */
    function withdraw(
        address tokenAddress,
        uint256 amount,
        address payable to,
        bytes32 tx_hash,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s,
        address from
    )
    public
    {
        emit AddressEvent(masterAddress);
        // trusted call
        masterInstance.withdraw(tokenAddress, amount, to, tx_hash, v, r, s, from);
    }

    /**
     * Mint specified amount of ether or one of ERC-20 tokens to provided address
     * @param tokenAddress address to mint
     * @param amount how much to mint
     * @param beneficiary destination address
     * @param txHash hash of transaction from Iroha
     * @param v array of signatures of tx_hash (v-component)
     * @param r array of signatures of tx_hash (r-component)
     * @param s array of signatures of tx_hash (s-component)
     * @param from relay contract address
     */
    function mintTokensByPeers(
        address tokenAddress,
        uint256 amount,
        address beneficiary,
        bytes32 txHash,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s,
        address from
    )
    public
    {
        emit AddressEvent(masterAddress);
        // trusted call
        masterInstance.mintTokensByPeers(tokenAddress, amount, beneficiary, txHash, v, r, s, from);
    }
}
