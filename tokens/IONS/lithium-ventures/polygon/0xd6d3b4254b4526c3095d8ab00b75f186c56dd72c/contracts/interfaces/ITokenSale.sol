// SPDX-License-Identifier: UNLICENSED


/**
 * @title ITokenSale.
 * @dev interface of ITokenSale
 * params structure and functions.
 */
pragma solidity ^0.8.4;

interface ITokenSale {

    struct Staked {
        uint128 amount;
        uint120 share;
        bool claimed;
    }

    enum Epoch {
        Incoming,
        Private,
        Finished
    }

    /**
     * @dev describe initial params for token sale
     * @param totalSupply set total amount of tokens. (Token decimals)
     * @param privateStart set starting time for private sale.
     * @param privateEnd set finish time for private sale.
     * @param privateTokenPrice set price for private sale per token in $ (18 decimals).
     * @param airdrop - amount reserved for airdrop
     */
    struct Params {
        uint96 totalSupply; //MUST BE 10**18;
        uint32 privateStart;
        uint96 privateTokenPrice; // MUST BE 10**18 in $  
        uint32 privateEnd;
    }

    struct State {
        uint128 totalPrivateSold;
        uint128 totalSupplyInValue;
    }

 
    /**
     * @dev initialize implementation logic contracts addresses
     * @param _stakingContract for staking contract.
     * @param _admin for admin contract.
     */
    function initialize(
        Params memory params,
        address _stakingContract,
        address _admin
    ) external;

    /**
     * @dev claim to sell tokens in airdrop.
     */
    // function claim() external;

    /**
     * @dev get banned list of addresses from participation in sales in this contract.
     */
    function epoch() external returns (Epoch);
    function destroy() external;
    function checkingEpoch() external;
    function totalTokenSold() external view returns (uint128);
    function giftTier(address[] calldata users, uint256[] calldata tiers) external;
    function stakes(address)
        external
        returns (
            uint128,
            uint120,
            bool
        );

    function takeLocked() external;
    function removeOtherERC20Tokens(address) external;
    function canClaim(address) external returns (uint120, uint256);
    function takeUSDCRaised() external;

    event DepositPrivate(address indexed user, uint256 amount, address instance);
    event Claim(address indexed user, uint256 change);
    event TransferAirdrop(uint256 amount);
    event TransferLeftovers(uint256 earned);
    event ERC20TokensRemoved(address _tokenAddress, address sender, uint256 balance);
    event RaiseClaimed(address _receiver, uint256 _amountInBUSD);
}
