// SPDX-License-Identifier: -- 💰 --

pragma solidity ^0.7.3;

import "./Snapshot.sol";

contract Token is Snapshot {

    using SafeMath for uint256;

    /**
    * @notice Moves amount tokens from the caller’s account to recipient.
    * Returns a boolean value indicating whether the operation succeeded.
    * @dev See {IERC20-transfer}.
    * Emits an {Transfer} event indicating a successful transfer.
    * @param _receiver -- recipient of amount
    * @param _amount -- amount that is transferred
    * @return true if transfer() succeeds
    */
    function transfer(
        address _receiver,
        uint256 _amount
    )
        external
        returns (bool)
    {
        require(
            _transferCheck(
                msg.sender,
                _receiver,
                _amount,
                false
            ),
            'Token: _transferCheck failed'
        );

        balances[msg.sender] =
        balances[msg.sender].sub(_amount);

        balances[_receiver] =
        balances[_receiver].add(_amount);

        emit Transfer(
            msg.sender,
            _receiver,
            _amount
        );

        return true;
    }

    /**
    * @notice Moves amount tokens from sender to recipient using the allowance mechanism.
    * Amount is then deducted from the caller’s allowance.
    * Returns a boolean value indicating whether the operation succeeded.
    * @dev See {IERC20-transferFrom}.
    * Emits an {Transfer} event indicating a successful transfer.
    * @param _owner -- address who is sending the transfer amount
    * @param _receiver -- recipient of amount
    * @param _amount -- amount that is transferred
    * @return true if transferFrom() succeeds
     */
    function transferFrom(
        address _owner,
        address _receiver,
        uint256 _amount
    )
        external
        returns (bool)
    {
        require(
            _transferCheck(
                _owner,
                _receiver,
                _amount,
                false
            ),
            'Token: _transferCheck failed'
        );

        require(
            allowances[_owner][msg.sender] >= _amount,
            'Token: exceeding allowance'
        );

        allowances[_owner][msg.sender] =
        allowances[_owner][msg.sender].sub(_amount);

        balances[_owner] =
        balances[_owner].sub(_amount);

        balances[_receiver] =
        balances[_receiver].add(_amount);

        emit Transfer(
            _owner,
            _receiver,
            _amount
        );

        return true;
    }

    /**
    * @notice Sets amount as the allowance of spender over the caller’s tokens.
    * @dev See {IERC20-approve}.
    * Emits an {Approval} event indicating how much was approved and whom is the spender
    * @param _spender -- approved address
    * @param _amount -- amount that they are approved to spend
    * @return true if Approve() succeeds
    */
    function approve(
        address _spender,
        uint256 _amount
    )
        external
        returns (bool)
    {

        allowances[msg.sender][_spender] = _amount;

        emit Approval(
            msg.sender,
            _spender,
            _amount
        );

        return true;
    }

    /**
    * @notice Returns the amount of tokens owned by account.
    * @dev See {IERC20-approve}.
    * @param _address -- address whose balance will be returned
    * @return balance[] value of the input address
    */
    function balanceOf(
        address _address
    )
        external
        view
        returns (uint256)
    {
        return balances[_address];
    }

    /**
    * @notice Returns the remaining number of tokens that spender will be allowed to spend
    * on behalf of owner through transferFrom. This is zero by default.
    * This value changes when approve or transferFrom are called.
    * @dev See {IERC20-allowance}.
    * @param _owner -- owner address
    * @param _spender -- address that is approved to spend tokens
    * @return allowances[] value of the input addresses to reflect the value mapped to the _spender's address
    */
    function allowance(
        address _owner,
        address _spender
    )
        external
        view
        returns (uint256)
    {
        return allowances[_owner][_spender];
    }
}