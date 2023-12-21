// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.18;

import {IIndexToken} from "src/interfaces/IIndexToken.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

/// @title AMKT Token
/// @author Alongside Finance
/// @notice The main token contract for AMKT (Alongside Finance)
/// @dev This contract uses an upgradeable pattern
contract IndexToken is ERC20VotesUpgradeable, IIndexToken {
    ///=============================================================================================
    /// Alongside
    ///=============================================================================================

    /// @notice Slot for minter address
    /// @notice cast keccak Alongside::Token::MinterSlot
    bytes32 public constant MINTER_SLOT =
        0x1af730152eea9813c49583a406e8dd55a4df08cae9e33ae45721374fdde82bae;

    /// @dev Make sure storage slots used in previous versions are not reused
    uint256[6] private __gap;

    ///=============================================================================================
    /// Modifiers
    ///=============================================================================================

    modifier onlyMinter() {
        require(msg.sender == minter(), "IndexToken: caller is not the minter");
        _;
    }

    ///=============================================================================================
    /// Initializer
    ///=============================================================================================

    /// @notice Initializer function called at time of deployment
    /// @param _minter address
    function initialize(address _minter) external override {
        require(minter() == address(0), "IndexToken: already initialized");

        // inline ERC20Permit__init becauase of initializer
        bytes32 hashedName = keccak256(bytes(name()));
        bytes32 hashedVersion = keccak256(bytes("2"));

        assembly {
            sstore(101, hashedName)
            sstore(102, hashedVersion)
        }

        Checkpoint[] storage _totalSupplyCheckpoints;
        assembly {
            _totalSupplyCheckpoints.slot := 206
        }

        _totalSupplyCheckpoints.push(
            Checkpoint({
                fromBlock: uint32(block.number - 1),
                votes: uint224(totalSupply())
            })
        );

        assembly {
            sstore(MINTER_SLOT, _minter)
        }

        emit MinterSet(_minter);
    }

    ///=============================================================================================
    /// Mint Logic
    ///=============================================================================================

    /// @notice External mint function
    /// @dev Mint function can only be called externally by the controller
    /// @param to address
    /// @param amount uint256
    function mint(address to, uint256 amount) external override onlyMinter {
        _mint(to, amount);
    }

    /// @notice External burn function
    /// @dev burn function can only be called externally by the controller
    /// @param from address
    /// @param amount uint256
    function burn(address from, uint256 amount) external override onlyMinter {
        _burn(from, amount);
    }

    ///=============================================================================================
    /// Storage
    ///=============================================================================================

    /// @notice Get the minter address
    /// @return minter_ address
    function minter() public view override returns (address minter_) {
        assembly {
            minter_ := sload(MINTER_SLOT)
        }
    }
}
