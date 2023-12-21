// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.17;

/**
 * @dev This interface is a slightly modified version of the IERC20 standard interface
 * To comply with the financial regulations(KYC, AML, Sanctions&Embargos), transfers need to be validated by an operator (the registrar operator)
 * before the tokens are actually transferred
 */
interface ISmartCoin {
    /**
     * @dev Emitted when a transfer request is initiated
     */
    event TransferRequested(
        bytes32 transferHash,
        address indexed from,
        address indexed to,
        uint256 value
    );
    /**
     * @dev Emitted when a transfer request is rejected
     */
    event TransferRejected(bytes32 transferHash);
    /**
     * @dev Emitted when a transfer request is validated
     */
    event TransferValidated(bytes32 transferHash);

    /**
     * @dev Burns a `amount` amount of tokens from the caller.
     */
    function burn(uint256 amount) external returns (bool);

    /**
     * @dev Mints a `amount` amount of tokens on `to` address
     */
    function mint(address to, uint256 amount) external returns (bool);

    /**
     * @dev Recalls a `amount` amount of tokens from `from` address
     * The tokens are transferred back to the registrar operator
     */
    function recall(address from, uint256 amount) external returns (bool);

    /**
     * @dev Same semantic as ERC20's transfer function although there are 2 cases :
     * 1- if the destination address is neither the registar operator's nor the operations operator's,
     * then the transfer will occur right away
     * 2 - if the destination is either the registrar operator's or the operations operator's
     * then the transfer will only actually occur once validated by the registrar operator
     * using the validateTransfer method
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.     *
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `requestedDecrease`.
     *
     * NOTE: Although this function is designed to avoid double spending with {approval},
     * it can still be frontrunned, preventing any attempt of allowance reduction.
     */
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool);

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool);

    /**
     * @dev Same semantic as ERC20's transferFrom function(no validation needed)
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    /**
     * @dev Actually performs the transfer request corresponding to the given `transferHash`
     * NB: only for transfers whose destination is either the registrar operator's address or the operations operator's
     * Called by the registrar operator
     */
    function validateTransfer(bytes32 transferHash) external returns (bool);

    /**
     * @dev Rejects(and thus, actually cancels) the transfer request corresponding to the given `transferHash`
     * NB: only for transfers whose destination is either the registrar operator's address or the operations operator's
     * Called by the registrar operator
     */
    function rejectTransfer(bytes32 transferHash) external returns (bool);

    /**
     * @dev Returns the balance of `addr` account
     */
    function balanceOf(address addr) external view returns (uint256);

    /**
     * @dev Returns current amount engaged in transfer requests for `addr` account
     */
    function engagedAmount(address addr) external view returns (uint256);

    /**
     * @dev Returns the contract's operators' addresses
     */
    function getOperators()
        external
        view
        returns (address registrar, address operations, address technical);

    /* start performed by openzeppelin ERC20 
     * function allowance(address owner, address spender)                            
     *        external                                                               
     *        view                                                                   
     *        returns (uint256);                                                     
     * function totalSupply(address) external view returns (uint256);                
     * event Transfer(address indexed from, address indexed to, uint256 value);      
     * event Approval(                                                               
     *   address indexed owner,                                                      
     *   address indexed spender,                                                    
     *   uint256 value                                                               
     * );                                                                            
    end performed by openzeppelin ERC20 */
}
