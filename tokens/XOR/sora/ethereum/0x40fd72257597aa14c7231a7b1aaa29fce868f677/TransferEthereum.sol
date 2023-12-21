pragma solidity ^0.5.8;

/**
 * Contract that sends Ether with internal transaction for testing purposes.
 */
contract TransferEthereum {


    /**
     * A special function-like stub to allow ether accepting
     */
    function() external payable {
        require(msg.data.length == 0);
    }

    function transfer(address payable to, uint256 amount) public {
        to.call.value(amount)("");
    }

}
