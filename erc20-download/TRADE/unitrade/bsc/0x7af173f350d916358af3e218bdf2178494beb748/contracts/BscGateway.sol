pragma solidity >=0.6.0 <0.7.0;
// SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BscGateway is ERC20, Ownable {
    mapping(bytes32 => bool) public processedRequests;

    event TransferredToEthereum(address from, uint256 amount);
    event TransferredFromEthereum(
        bytes32 requestTxHash,
        address to,
        uint256 amount
    );

    constructor() public ERC20("UniTrade", "TRADE") {}

    function transferFromEthereum(
        bytes32 requestTxHash,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(
            !processedRequests[requestTxHash],
            "BscGateway: request already processed"
        );
        processedRequests[requestTxHash] = true;
        _mint(to, amount);
        emit TransferredFromEthereum(requestTxHash, to, amount);
    }

    function transferToEthereum(uint256 amount) external {
        require(amount > 0, "BscGateway: amount should be > 0");
        _burn(msg.sender, amount);
        emit TransferredToEthereum(msg.sender, amount);
    }
}
