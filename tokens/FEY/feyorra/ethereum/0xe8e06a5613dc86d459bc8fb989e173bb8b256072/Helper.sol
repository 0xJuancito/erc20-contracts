// SPDX-License-Identifier: -- 💰 --

pragma solidity ^0.7.3;

import './Timing.sol';
import './Ownable.sol';
import './Events.sol';
import './SafeMath.sol';

contract Helper is Ownable, Timing, Events {

    using SafeMath for uint256;

    /**
    * @notice burns set amount of tokens
    * @dev currently unused based on changing requirements
    * @param _amount -- amount to be burned
    * @return true if burn() succeeds
    */
    function burn(
        uint256 _amount
    )
        external
        onlyOwner
        returns (bool)
    {
        require(
            balances[msg.sender].sub(_amount) >= 0,
            'FEYToken: exceeding balance'
        );

        totalSupply =
        totalSupply.sub(_amount);

        balances[msg.sender] =
        balances[msg.sender].sub(_amount);

        emit Transfer(
            msg.sender,
            address(0x0),
            _amount
       );

        return true;
    }

    /**
    * @notice Groups common requirements in global, internal function
    * @dev Used by Transfer(), TransferFrom(), OpenStake()
    * @param _sender -- msg.sender of the functions listed above
    * @param _recipient -- recipient of amount
    * @param _amount -- amount that is transferred
    * @param _allowBurnAddress -- boolean to allow burning tokens
    * @return balance[] value of the input address
    */
    function _transferCheck(
        address _sender,
        address _recipient,
        uint256 _amount,
        bool _allowBurnAddress
    )
        internal
        view
        returns (bool)
    {

        if (_allowBurnAddress == false) {
            require(
                _recipient != address(0x0),
                'FEYToken: cannot send to burn address'
            );
        }

        require(
            balances[_sender] >= _amount,
            'FEYToken: exceeding balance'
        );

        require(
            balances[_recipient].add(_amount) >= balances[_recipient],
            'FEYToken: overflow detected'
        );

        return true;
    }

    /**
    * @notice Used to calculate % that is staked out of the totalSupply
    * @dev Used by getYearlyInterestLatest(), getYearlyInterestHistorical(), + twice in getInterest()
    * @param _numerator -- numerator, typically globals.totalStakedAmount
    * @param _denominator -- denominator, typically totalSupply
    * @param _precision -- number of decimal points, fixed at 4
    * @return quotient -- calculated value
    */
    function getPercent(
        uint256 _numerator,
        uint256 _denominator,
        uint256 _precision
    )
        public
        pure
        returns(uint256 quotient)
    {
        uint256 numerator = _numerator * 10 ** (_precision + 1);
        quotient = ((numerator / _denominator) + 5) / 10;
    }

    /**
    * @notice Used to reduce value by a set percentage amount
    * @dev Used to calculate penaltyAmount
    * @param _value -- initial value, typically _stakeElement.stakedAmount
    * @param _perc -- percentage reduction that will be applied
    * @return percentageValue -- value reduced by the input percentage
    */
    function percentCalculator(
        uint256 _value,
        uint256 _perc
    )
        public
        pure
        returns (uint256 percentageValue)
    {
        percentageValue = _value
            .mul(_perc)
            .div(10000);
    }

}