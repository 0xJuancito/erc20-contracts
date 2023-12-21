// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
// import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {UnrenounceableOwnable2Step} from "./UnrenounceableOwnable2Step.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Rescuable is UnrenounceableOwnable2Step {
    using SafeERC20 for IERC20;

    address public rescuer;

    event RescuerChanged(address indexed newRescuer);

    /**
     * @notice Revert if called by any account other than the rescuer.
     */
    modifier onlyRescuer() {
        require(msg.sender == rescuer, "Rescuable: caller is not the rescuer");
        _;
    }

    constructor() {
        rescuer = msg.sender;
    }

    /**
     * @notice Rescue ERC20 tokens locked up in this contract.
     * @param tokenContract ERC20 token contract address
     * @param to        Recipient address
     * @param amount    Amount to withdraw
     */
    function rescueERC20(
        address tokenContract,
        address to,
        uint256 amount
    ) external onlyRescuer {
        IERC20(tokenContract).transfer(to, amount);
    }

    /**
     * @notice Assign the rescuer role to a given address.
     * @param newRescuer New rescuer's address
     */
    function updateRescuer(address newRescuer) external onlyOwner {
        require(
            newRescuer != address(0),
            "Rescuable: new rescuer is the zero address"
        );
        rescuer = newRescuer;
        emit RescuerChanged(newRescuer);
    }
}
