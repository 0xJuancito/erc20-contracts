/*-
 * SPDX-License-Identifier: MIT
 *
 * Copyright (c) 2021, Fearless Legends Pte Ltd
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 *
 * PLEASE READ THE TERMS SET OUT HEREIN CAREFULLY AND VERIFY ALL INFORMATION TO BE
 * CORRECT. THE AUTHORS OR COPYRIGHT HOLDERS SHALL NOT BE LIABLE FOR ANY INCORRECT
 * INFORMATION CONTAINED HEREIN.
 *
 * FXF TOKENS ARE NOT INTENDED TO CONSTITUTE SECURITIES OF ANY FORM, UNITS IN A
 * COLLECTIVE INVESTMENT SCHEME OR ANY OTHER FORM OF INVESTMENT IN ANY
 * JURISDICTION. THIS AGREEMENT DOES NOT CONSTITUTE A PROSPECTUS OR OFFER DOCUMENT
 * OF ANY SORT AND IS NOT INTENDED TO CONSTITUTE AN OFFER OF SECURITIES OF ANY
 * FORM, UNITS IN A COLLECTIVE INVESTMENT SCHEME OR ANY OTHER FORM OF INVESTMENT,
 * OR A SOLICITATION FOR ANY FORM OF INVESTMENT IN ANY JURISDICTION. NO REGULATORY
 * AUTHORITY HAS EXAMINED OR APPROVED THIS AGREEMENT, AND NO ACTION HAS BEEN OR
 * WILL BE TAKEN IN RESPECT OF OBTAINING SUCH APPROVAL UNDER THE LAWS, REGULATORY
 * REQUIREMENTS OR RULES OF ANY JURISDICTION.
 *
 * PLEASE NOTE THAT THE AUTHORS OR COPYRIGHT HOLDERS WILL NOT OFFER OR SELL TO
 * YOU, AND YOU ARE NOT ELIGIBLE TO PURCHASE ANY FXF TOKENS IF SUCH PURCHASE IS
 * PROHIBITED, RESTRICTED  OR UNAUTHORISED IN ANY FORM OR MANNER WHETHER IN FULL
 * OR IN PART UNDER THE LAWS, REGULATORY REQUIREMENTS OR RULES IN THE JURISDICTION
 * IN WHICH YOU ARE LOCATED OR SUBJECT TO.
 *
 * The Monetary Authority of Singapore (MAS) requires us to provide this risk
 * warning to you as a customer of a digital payment token (DPT) service provider.
 * Before you pay your DPT service provider any money or DPT, you should be aware
 * of the following.1.Your DPT service provider is exempted by MAS from holding a
 * license to provide DPT services. Please note that you may not be able to
 * recover all the money or DPTs you paid to your DPT service provider if your DPT
 * service provider’s business fails. 2.You should not transact in the DPT if you
 * are not familiar with this DPT. Transacting in DPTs may not be suitable for you
 * if you are not familiar with the technology that DPT services are
 * provided.3.You should be aware that the value of DPTs may fluctuate greatly.
 * You should buy DPTs only if you are prepared to accept the risk of losing all
 * of the money you put into such tokens.
 */

pragma solidity >=0.7.6 <0.8.0;
pragma abicoder v2;

/*

███████╗██╗███╗   ██╗██╗  ██╗███████╗██╗      ██████╗     ███████╗██╗  ██╗███████╗
██╔════╝██║████╗  ██║╚██╗██╔╝██╔════╝██║     ██╔═══██╗    ██╔════╝╚██╗██╔╝██╔════╝
█████╗  ██║██╔██╗ ██║ ╚███╔╝ █████╗  ██║     ██║   ██║    █████╗   ╚███╔╝ █████╗
██╔══╝  ██║██║╚██╗██║ ██╔██╗ ██╔══╝  ██║     ██║   ██║    ██╔══╝   ██╔██╗ ██╔══╝
██║     ██║██║ ╚████║██╔╝ ██╗██║     ███████╗╚██████╔╝    ██║     ██╔╝ ██╗██║
╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝     ╚═╝     ╚═╝  ╚═╝╚═╝

*/

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";


contract FXF is Initializable, ERC20Upgradeable, ERC20CappedUpgradeable {

    using SafeMathUpgradeable for uint256;

    address _governance;
    uint256 _version;


    /**
     * @dev deploy ERC20 token
     * @param name name of the token
     * @param symbol symbol of the token
     * @notice deployer is the governance
     */
    function initialize(string memory name, string memory symbol) public virtual initializer {
        __ERC20_init(name, symbol);
        __ERC20Capped_init(150 * 10**6 * 10**18);
        _mint(_msgSender(), 150 * 10**6 * 10**18);
        _governance = _msgSender();
        _version = 1;
    }


    struct LockInfo {
        address account;
        uint256 initialLockedTokens;
        uint256 lockedTokens;
        uint256[] amounts;
        uint256[] milestones;
        bool[] isClaimed;
        bool isLocked;
    }


    /**
     * @dev locking details
     */
    mapping (address => LockInfo) locks;

    /**
     * @dev Lock event triggered when an account is locked
     */
    event Lock(address account, uint256 amount);

    /**
     * @dev Unlock event triggered when an account unlocks tokens
     */
    event Unlock(address account, uint256 amount);


    /**
     * @dev lockInfo retreives the lock information of an account
     * @param account an account address
     * @return lock information for a given account
     */
    function lockInfo(address account) public view returns (LockInfo memory) {
        return locks[account];
    }

    /**
     * @dev isLocked is used to check the lock status of an account
     * @param account account to be checked
     */
    function isLocked(address account) public view returns (bool) {
        return locks[account].isLocked;
    }

    /**
     * @dev lockedTokens returns the number of locked tokens
     * @param account an account address
     * @return number of locked tokens for a given account
     */
    function lockedTokens(address account) public view returns (uint256) {
        return locks[account].lockedTokens;
    }

    /**
     * @dev Set Governance
     * @param governance_ the new governance
     * @notice can be set only by present governance address
     */
    function setGovernance(address governance_) public {
        require(_msgSender() == _governance, "!governance");
        require(governance_ != address(0), "governance can not be zero address");
        _governance = governance_;
    }

    /**
     * @dev unlockTokens is used by users to unlock tokens based on scheduled milestones
     */
    function unlockTokens() public {
        // Check if account has locked tokens
        require(isLocked(_msgSender()) == true, "Your wallet is not locked");

        // locking information
        LockInfo storage lock = locks[_msgSender()];

        // number of unlocked tokens
        uint256 unlockedTokens = 0;
        for (uint8 i = 0; i < lock.amounts.length; i++) {
            if (block.timestamp >= lock.milestones[i] && lock.isClaimed[i] == false) {
                unlockedTokens += lock.amounts[i];
                lock.isClaimed[i] = true;
            }
        }

        // update locked tokens
        lock.lockedTokens = lock.lockedTokens.sub(unlockedTokens);

        if(lock.lockedTokens == 0)
            lock.isLocked = false;

        emit Unlock(_msgSender(), unlockedTokens);
    }

    /**
     * @dev transferLock transfer to a recipient and lock it's wallet.
     * @param recipient the account address to be locked
     * @param amount number of tokens to transfer and lock
     * @param amounts amounts of tokens to unlock after each milestone
     * @param milestones milestones when the tokens will be unlocked
     */
    function transferLock(address recipient, uint256 amount, uint256[] memory amounts, uint256[] memory milestones) public {
        // only governance can transfer and lock
        require(_msgSender() == _governance, "!governance");

        // Can't lock already locked wallet
        require(isLocked(recipient) == false, "Already Locked");

        // Can't lock address zero
        require(recipient != address(0), "The recipient's address cannot be 0");

        // Can't lock zero tokens
        require(amount > 0, "Amount has to be greater than 0");

        // number of amounts & number of milestones should be equal
        require(amounts.length == milestones.length, "Length of amounts & length of milestones must be equal");

        // sum of amounts should be equal to amount
        require(_sum(amounts) == amount, "Sum of amounts must equals to transfered amount");

        // init all claimed milestones to false
        bool[] memory isClaimed = _initArrayBool(milestones.length, false);

        // 1. lock
        locks[recipient] = LockInfo(recipient, amount, amount, amounts, milestones, isClaimed, true);

        // 2. transfer
        transfer(recipient, amount);

        // Lock event will be triggered
        emit Lock(recipient, amount);
    }


    /**
     * @dev _beforeTokenTransfer used override the check if the user is allowed to transfer the tokens or not
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override (ERC20Upgradeable, ERC20CappedUpgradeable){
        super._beforeTokenTransfer(from, to, amount);

        // Check if the User is allowed to transfer the tokens or not
        require(_canTransfer(from, amount) == true, "Can not transfer locked tokens");
    }

    /**
     * @dev canTransfer used to check if the user is allowed to transfer the token or not
     * @param from account address of the user who wants to transfer
     * @param amount is the amount to planned to transfer
     */
    function _canTransfer(address from, uint256 amount) private view returns (bool) {
        if (isLocked(from) == true) {
            uint256 transferable = balanceOf(from).sub(lockedTokens(from));
            return (transferable >= amount);
        }
        return true;
    }

    /**
     * @dev _initArrayBool pure function is used to init an bool[]
     */
    function _initArrayBool(uint256 size, bool value) private pure returns (bool[] memory isClaimed) {
        isClaimed = new bool[](size);
        for (uint256 i = 0; i < size; i++) {
            isClaimed[i] = value;
        }
        return isClaimed;
    }

    /**
     * @dev _sum pure function to sum elements in an array
     * @param array array of elements
     */
    function _sum(uint256[] memory array) private pure returns (uint256 sum) {
        sum = 0;
        for (uint8 i = 0; i < array.length; i++) {
            sum += array[i];
        }
        return sum;
    }
}
