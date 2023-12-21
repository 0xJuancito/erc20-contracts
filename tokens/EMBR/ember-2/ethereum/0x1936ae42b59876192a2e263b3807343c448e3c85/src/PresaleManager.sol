// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "solmate/auth/Owned.sol";
import "./IEMBR.sol";
import "solady/src/utils/ECDSA.sol";

using ECDSA for bytes32;

contract EMBRPresale is Owned {
    IEMBRToken public ember_token;

    uint public total_commited_eth;
    uint public hard_cap = 500.01 ether;

    uint public precision = 10**21;

    uint public commit_start;
    uint public commit_length;

    mapping(address => uint) public commited_amount;
    mapping(address => uint) public claimed;

    uint public vesting_start;
    uint public cliff_period = 14 days;
    uint public vesting_period = 90 days;

    uint public PRICE_PER_TOKEN = 0.00016667 ether;

    address public claimSigner;

    event Commit(address indexed from, uint commit_amount, uint total_commitment);

    constructor(address _claimSigner, uint _commitStart, uint _commitLength) Owned(msg.sender) {
        claimSigner = _claimSigner;

        commit_start = _commitStart;
        commit_length = _commitLength;
    }

    function commit(bytes memory signature, uint min_allocation, uint max_allocation) payable public {
        require(block.timestamp >= commit_start, "Sale is not live yet");
        require(block.timestamp < (commit_start + commit_length), "Sale already ended");

        require(msg.value > 0, "Commitment amount too low");

        // Verify signature & allocation size
        bytes32 hashed = keccak256(abi.encodePacked(msg.sender, min_allocation, max_allocation));
        bytes32 message = ECDSA.toEthSignedMessageHash(hashed);
        address recovered_address = ECDSA.recover(message, signature);
        require(recovered_address == claimSigner, "Invalid signer");

        uint user_commited_amount = commited_amount[msg.sender];
        require(user_commited_amount >= min_allocation || msg.value >= min_allocation, "Minimum presale commitment not met");

        uint allocation_available = max_allocation - user_commited_amount;

        uint leftFromHardCap = hard_cap - total_commited_eth;
        if (leftFromHardCap < allocation_available) allocation_available = leftFromHardCap;

        require(allocation_available > 0, "No more allocation left");

        uint commit_amount = msg.value;

        // If the user is trying to commit more than they have allocated, refund the difference and proceed
        if (msg.value > allocation_available) {
            uint leftover = msg.value - allocation_available;

            (bool sent,) = msg.sender.call{value: leftover}("");
            require(sent, "Failed to send Ether");

            commit_amount -= leftover;
        }

        commited_amount[msg.sender] += commit_amount;
        total_commited_eth += commit_amount;

        emit Commit(msg.sender, commit_amount, commited_amount[msg.sender]);
    }

    function claim() external returns (uint) {
        require(vesting_start != 0, "vesting hasnt started yet bro");
        require(block.timestamp >= vesting_start + cliff_period, "You can only start claiming after cliff period");

        uint passedTime = block.timestamp - vesting_start;
        if (passedTime > vesting_period) passedTime = vesting_period;

        uint totalUserTokens = commited_amount[msg.sender] * 10**18 / PRICE_PER_TOKEN;
        uint totalClaimableTokens = totalUserTokens * precision * passedTime / vesting_period / precision;
        uint toClaim = totalClaimableTokens - claimed[msg.sender];

        claimed[msg.sender] += toClaim;

        ember_token.mintWithAllowance(toClaim, msg.sender);

        return toClaim;
    }

    function claimable() external view returns (uint) {
        if (vesting_start == 0) return 0;
        if (block.timestamp < vesting_start + cliff_period) return 0;

        uint passedTime = block.timestamp - vesting_start;
        if (passedTime > vesting_period) passedTime = vesting_period;

        uint totalUserTokens = commited_amount[msg.sender] * 10**18 / PRICE_PER_TOKEN;
        uint totalClaimableTokens = totalUserTokens * precision * passedTime / vesting_period / precision;
        uint toClaim = totalClaimableTokens - claimed[msg.sender];

        return toClaim;
    }

    function withdraw() onlyOwner external {
        (bool sent,) = owner.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    function startVesting() onlyOwner external {
        vesting_start = block.timestamp;
    }

    function setEmbr(address embr) onlyOwner external {
        ember_token = IEMBRToken(embr);
    }

    function setCommitInfo(uint startTs, uint length) onlyOwner external {
        commit_start = startTs;
        commit_length = length;
    }

    function setHardCap(uint new_hardcap) onlyOwner external {
        hard_cap = new_hardcap;
    }
}
