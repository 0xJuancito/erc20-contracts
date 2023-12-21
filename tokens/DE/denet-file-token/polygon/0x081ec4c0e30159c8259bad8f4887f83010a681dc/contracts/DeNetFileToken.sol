// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
    ***********************************************************
    ** DeNet File Token - $DE
    ** Governance Utility Token for DeNet DAO originzed to
    ** manages the DeNet Storage Protocol (DeNet SP).
    ** 
    ** Target Usage - DAO.
    **
    ** Utility Token Targets:
    **     - Voting for functonality inside DeNet Storage
    **       Protocol (Proof Of Storage)
    **     - Using inside issue new gas token (TB/Year)
    **       inside DeNet Storage Protocol (Proof Of Storage)
    **     - Distribution, popularization and load on the DeNet
    **       Storage Protocol
    **     - DeNet Storage Protocol design and development
    ***********************************************************
    */
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20Vesting.sol";
import "./Constant.sol";

import "./interfaces/IShares.sol";
import "./interfaces/IDeNetFileToken.sol";


/**
    * @dev this contract do shares "pie" from choosen parts for token
    */
contract Shares is DeNetFileTokenConstants, IShares {
    uint public constant tenYearsSupply = _CONST_BILLION;
    uint64 public timeNextYear = 0;
    uint8 public currentYear = 0;

    address public treasury = address(0);

    /**
        * @dev Supply of year's inside array
        */
    uint[10] public supplyOfYear = [
        145 * _CONST_MILLION,
        128 * _CONST_MILLION,
        121 * _CONST_MILLION,
        112 * _CONST_MILLION,
        104 * _CONST_MILLION,
        95 * _CONST_MILLION,
        87 * _CONST_MILLION,
        79 * _CONST_MILLION,
        71 * _CONST_MILLION, 
        58 * _CONST_MILLION
    ];

    /**
        * @dev Vesting contract addresses
        */
    address[10] public vestingOfYear;

    /**
        * @dev Divider of 100% for shares calculating (ex: 100000 = 100%, 1000 - 1%)
        */
    uint32 public constant sharesRatio = 100000;

    mapping (address => uint) public shares;
    mapping (uint32 => address) public sharesVector;
    uint32 public sharesCount = 0;
    uint32 public sharesAvailable = sharesRatio;

    /**
        * @dev add shares for _reciever (can be contract)
        * @param _reciever address of shareholder
        * @param _size part of 100k sharesRatio (0-100k) < sharesAvailable
        */
    function _addShares(address _reciever, uint32 _size) internal {
        require(sharesAvailable >= _size, "Shares: Wrong size");

        /**
        * @dev check is already exist _reciever. It can be useful after removing and add address back
        */
        bool _reciever_already_exist = false;
        for (uint32 i = 0; i < sharesCount; i++) {
            if (sharesVector[i] == _reciever) {
                _reciever_already_exist = true;
                break;
            }
        }

        if (!_reciever_already_exist) {
            sharesVector[sharesCount] = _reciever;
            sharesCount = sharesCount + 1;
        }
        
        shares[_reciever] = shares[_reciever] + _size;
        sharesAvailable = sharesAvailable - _size;
        emit NewShares(_reciever, _size);
    }

    /**
        * @dev remove shares for _reciever (can be contract)
        * @param _reciever address of shareholder
        * @param _size part of 100k sharesRatio (0-100k) <= shares[_reciever]
        */
    function _removeShares(address _reciever, uint32 _size) internal  {
        require(shares[_reciever] >= _size, "Shares: Shares < _size");

        shares[_reciever] = shares[_reciever] - _size;
        sharesAvailable = sharesAvailable + _size;
        
        // removing address from sharesVector
        if (shares[_reciever] == 0) {
            for (uint32 i = 0; i < sharesCount; i++) {
                if (sharesVector[i] == _reciever) {
                    sharesVector[i] = sharesVector[sharesCount];
                    sharesVector[sharesCount] = address(0);
                    sharesCount--;
                    break;
                }
            }
        }
        
        emit DropShares(_reciever, _size);
    }

}

/**
 * @dev This contract is ERC20 token with special 10 years form of distribution with linear vesting.
 */
contract DeNetFileToken is ERC20, Shares, Ownable, IDeNetFileToken {

    constructor (string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(address(this), tenYearsSupply);
    }

    /**
     * @notice see Shares._addShares(_reciever, _size);
     */
    function addShares(address _reciever, uint32 _size) external onlyOwner {
        _addShares(_reciever, _size);
    }

    /**
     * @notice see Shares._removeShares(_reciever, _size);
     */
    function removeShares(address _reciever, uint32 _size) external onlyOwner  {
       _removeShares(_reciever, _size);
    }

    /**
        *  @dev Minting year supply with shares and vesting
        *
        * Input: None
        * Output: None
        *
        *  What this function do?
        *  Step 1. Check Anything
        *  1. Check is block.timestamp > timeNextYear (previous year is ended)
        *  2. Check sharesCount > 0 (is Supply has a Pie
        *  3. Check is it year <= 10
        * 
        *  Step 2. Deploy Vesting and Transfer
        *  4. Deploy ERC20Vesting as theVesting
        *  5. Set linear vesting time start as block.timestamp and end time as time start + one year
        *  6. Set vestingOfYear[currentYear] = theVesting.address
        *  7. DeNetFileToken.transfer tokens from main contract to theVesting.address in total supplyOfYear[currentYear]
        *
        *  Step 3. Set Vesting for shareholders
        *  8. call theVesting.createVesting(sharesVector[0-sharesCount], _timestart, _timeend, sendAmount) where sendAmount = shares[_reciever] * supplyOfYear[currentYear]  / sharesRatio
        *  9. call theVesting.createVesting(treasury, _timestart, _timeend, sendAmount)), where sendAmount = sharesAvailable * supplyOfYear[currentYear] / sharesRatio
        *
        *  Step 4. Prepeare for next year
        *  10. Reset treasury address
        *  11. currentYear++
        *  12. timeNextYear = now + 1 year.
        *  13, Emit event NewYear(currentYear, timeNextYear)
        */
    function smartMint() external onlyOwner {

        // Step 1. Check Anything
        require(block.timestamp > timeNextYear, "Main: Time is not available");
        require(sharesCount > 0, "Main: Shares count = 0");
        require(currentYear < supplyOfYear.length, "Main: 10Y");
        
        // Step 2. Deploy Vesting and Transfer
        ERC20Vesting theVesting = new ERC20Vesting(address(this));
        
        vestingOfYear[currentYear] = address(theVesting);
        _transfer(address(this), address(theVesting), supplyOfYear[currentYear]);
        
        uint64 _timestart = uint64(block.timestamp);
        uint64 _timeend = _timestart + _CONST_ONEYEAR; 
        uint transfered = 0;
        

        // Step 3. Set Vesting for shareholders
        for (uint32 i = 0; i < sharesCount; i = i + 1) {
            uint sendAmount = supplyOfYear[currentYear] * shares[sharesVector[i]] / sharesRatio;
            if (sendAmount == 0) continue;
            theVesting.createVesting(sharesVector[i], _timestart, _timeend, sendAmount);
            transfered = transfered + sendAmount;
        }
         
        uint _treasuryAmount = supplyOfYear[currentYear] - transfered;
        if (_treasuryAmount > 0) {
            require(treasury != address(0), "Main: This year treasury not set!");
            theVesting.createVesting(treasury, _timestart, _timeend, _treasuryAmount);
        }
        
        // Step 4. Prepeare for next year
        treasury = address(0);
        timeNextYear = uint64(block.timestamp) + _CONST_ONEYEAR; // move next year;
        currentYear = currentYear + 1;
        emit NewYear(currentYear, timeNextYear);
    }

    function setTreasury(address _new) external onlyOwner {
        require(_new != address(0), "Main: _new = zero");
        require(_new != address(this), "Main: _new = this");

        treasury = _new;
        emit UpdateTreasury(_new, currentYear);
    }
}