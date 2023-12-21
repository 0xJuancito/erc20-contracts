// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;
import "./ERC20/BEP20.sol";
import "./ERC20/IBEP20.sol";
import "./ERC20/SafeBEP20.sol";
import "./access/Ownable.sol";

contract MAT is BEP20, Ownable {
    using SafeBEP20 for IBEP20;

    constructor()
        BEP20("mymasterwar.com", "MAT")
    {
        _mint(
            0xfd22D86bE8C45082C225741F152Cbac7003D145e,
            25000000000000000000000000
        ); //25% token ecosystem
        _mint(
            0xa48f87AA888d9a341140562e8c094dE45b62fE90,
            10500000000000000000000000
        ); //10.5% Liquidity & marketing:
        _mint(
            0xF3a3F29C1F846CbDe9A17A161DF4c68243e3003f,
            15000000000000000000000000
        ); //15% Treasury
        _mint(
            0x30c48731e978A876500b6e521b87139c2246771C,
            12000000000000000000000000
        ); //12% Private Round
        _mint(
            0xA1CE933CE3384E1e9c3E27EE239d5c08b63F3dA6,
            2500000000000000000000000
        ); //2.5% Public round
        _mint(
            0xda9D2d8e320f4C05e41C0ACEb92B89F1c347BFeA,
            20000000000000000000000000
        ); //20% team + advisor
        _mint(
            0x9E1850F4802e43e5E05C7C6d7D6ef4ddBb1E195c,
            15000000000000000000000000
        ); //15% Play to earn
    }

    /* ========== EMERGENCY ========== */
    /*
    Users make mistake by transfering usdt/busd ... to contract address. 
    This function allows contract owner to withdraw those tokens and send back to users.
    */
    function rescueStuckErc20(address _token) external onlyOwner {
        uint256 _amount = IBEP20(_token).balanceOf(address(this));
        IBEP20(_token).safeTransfer(owner(), _amount);
    }
}
