// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

import "./_BlockwellQuill.sol";
import "./_Type.sol";
import "./_VotingPrime.sol";

/**
 * Blockwell Prime Token
 */
contract PrimeToken is VotingPrime, Type {
    using BlockwellQuill for BlockwellQuill.Data;

    string public attorneyEmail;

    BlockwellQuill.Data bwQuill1;

    event BwQuillSet(address indexed account, string value);

    event Payment(address indexed from, address indexed to, uint256 value, uint256 order);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) {
        require(_totalSupply > 0);

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        totalTokenSupply = _totalSupply;

        init(msg.sender);
        bwtype = PRIME;
        bwver = 76;
    }

    function init(address sender) internal virtual {
        _addBwAdmin(sender);
        _addAdmin(sender);

        balances[sender] = totalTokenSupply;
        emit Transfer(address(0), sender, totalTokenSupply);
    }

    /**
     * @dev Set a quill 1 value for an account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function setBwQuill(address account, string memory value) public onlyAdminOrAttorney {
        bwQuill1.setString(account, value);
        emit BwQuillSet(account, value);
    }

    /**
     * @dev Get a quill 1 value for any account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getBwQuill(address account) public view returns (string memory) {
        return bwQuill1.getString(account);
    }

    /**
     * @dev Update the email address for this token's assigned attorney.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function setAttorneyEmail(string memory email) public onlyAdminOrAttorney {
        attorneyEmail = email;
    }

    /**
     * @dev Withdraw any tokens the contract itself is holding.
     */
    function withdrawTokens(Erc20 token, uint256 value) public whenNotPaused {
        expect(isAdmin(msg.sender), ERROR_UNAUTHORIZED);
        expect(address(token) != address(this), ERROR_BAD_PARAMETER_1);
        expect(token.transfer(msg.sender, value), ERROR_TRANSFER_FAIL);
    }
    
    /**
     * @dev Withdraws all ether this contract holds.
     */
    function withdraw() public {
        expect(isAdmin(msg.sender), ERROR_UNAUTHORIZED);
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev Transfer tokens and include an order number for external reference.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function payment(
        address to,
        uint256 value,
        uint256 order
    ) public whenNotPaused whenUnlocked returns (bool) {
        _transfer(msg.sender, to, value);

        emit Payment(msg.sender, to, value, order);
        return true;
    }
}
