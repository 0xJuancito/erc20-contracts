// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/lib/UncheckedMemory.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Metadata.sol";

// a library for abstracting tokens
// provides a common interface for ERC20, ERC1155, and ERC721 tokens.

bytes32 constant TOKEN_MASK = 0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
bytes32 constant ID_MASK = 0x00FFFFFFFFFFFFFFFFFFFFFF0000000000000000000000000000000000000000;

uint256 constant ID_SHIFT = 160;
bytes32 constant TOKENSPEC_MASK = 0xFF00000000000000000000000000000000000000000000000000000000000000;

string constant NATIVE_TOKEN_SYMBOL = "ETH";

type Token is bytes32;

type TokenSpecType is bytes32;

using {TokenSpec_equals as ==} for TokenSpecType global;
using {Token_equals as ==} for Token global;
using {Token_lt as <} for Token global;
using {Token_lte as <=} for Token global;
using {Token_ne as !=} for Token global;

using UncheckedMemory for Token[];

Token constant NATIVE_TOKEN = Token.wrap(0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE);

function TokenSpec_equals(TokenSpecType a, TokenSpecType b) pure returns (bool) {
    return TokenSpecType.unwrap(a) == TokenSpecType.unwrap(b);
}

function Token_equals(Token a, Token b) pure returns (bool) {
    return Token.unwrap(a) == Token.unwrap(b);
}

function Token_ne(Token a, Token b) pure returns (bool) {
    return Token.unwrap(a) != Token.unwrap(b);
}

function Token_lt(Token a, Token b) pure returns (bool) {
    return Token.unwrap(a) < Token.unwrap(b);
}

function Token_lte(Token a, Token b) pure returns (bool) {
    return Token.unwrap(a) <= Token.unwrap(b);
}

library TokenSpec {
    TokenSpecType constant ERC20 =
        TokenSpecType.wrap(0x0000000000000000000000000000000000000000000000000000000000000000);

    TokenSpecType constant ERC721 =
        TokenSpecType.wrap(0x0100000000000000000000000000000000000000000000000000000000000000);

    TokenSpecType constant ERC1155 =
        TokenSpecType.wrap(0x0200000000000000000000000000000000000000000000000000000000000000);

    TokenSpecType constant NATIVE =
        TokenSpecType.wrap(0xEE00000000000000000000000000000000000000000000000000000000000000);
}

function toToken(IERC20 tok) pure returns (Token) {
    return Token.wrap(bytes32(uint256(uint160(address(tok)))));
}

function toToken(TokenSpecType spec_, uint88 id_, address addr_) pure returns (Token) {
    return Token.wrap(
        TokenSpecType.unwrap(spec_) | bytes32((bytes32(uint256(id_)) << ID_SHIFT) & ID_MASK)
            | bytes32(uint256(uint160(addr_)))
    );
}

// binary search on sorted arrays
function _binarySearch(Token[] calldata arr, Token token) view returns (uint256) {
    if (arr.length == 0) return type(uint256).max;
    uint256 start = 0;
    uint256 end = arr.length - 1;
    unchecked {
        while (start <= end) {
            uint256 mid = start + (end - start) / 2;
            if (arr.uc(mid) == token) {
                return mid;
            } else if (arr.uc(mid) < token) {
                start = mid + 1;
            } else {
                if (mid == 0) return type(uint256).max;
                end = mid - 1;
            }
        }
    }
    return type(uint256).max;
}

// binary search on sorted arrays, memory array version
function _binarySearchM(Token[] memory arr, Token token) view returns (uint256) {
    if (arr.length == 0) return type(uint256).max;
    uint256 start = 0;
    uint256 end = arr.length - 1;
    unchecked {
        while (start <= end) {
            uint256 mid = start + (end - start) / 2;
            if (arr.u(mid) == token) {
                return mid;
            } else if (arr.u(mid) < token) {
                start = mid + 1;
            } else {
                if (mid == 0) return type(uint256).max;
                end = mid - 1;
            }
        }
    }
    return type(uint256).max;
}

library TokenLib {
    using TokenLib for Token;
    using TokenLib for bytes32;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    function wrap(bytes32 data) internal pure returns (Token) {
        return Token.wrap(data);
    }

    function unwrap(Token tok) internal pure returns (bytes32) {
        return Token.unwrap(tok);
    }

    function addr(Token tok) internal pure returns (address) {
        return address(uint160(uint256(tok.unwrap() & TOKEN_MASK)));
    }

    function id(Token tok) internal pure returns (uint256) {
        return uint256((tok.unwrap() & ID_MASK) >> ID_SHIFT);
    }

    function spec(Token tok) internal pure returns (TokenSpecType) {
        return TokenSpecType.wrap(tok.unwrap() & TOKENSPEC_MASK);
    }

    function toIERC20(Token tok) internal pure returns (IERC20Metadata) {
        return IERC20Metadata(tok.addr());
    }

    function toIERC1155(Token tok) internal pure returns (IERC1155) {
        return IERC1155(tok.addr());
    }

    function toIERC721(Token tok) internal pure returns (IERC721Metadata) {
        return IERC721Metadata(tok.addr());
    }

    function balanceOf(Token tok, address user) internal view returns (uint256) {
        if (tok.spec() == TokenSpec.ERC20) {
            require(tok.id() == 0);
            return tok.toIERC20().balanceOf(user); // ERC721 balanceOf() has the same signature
        } else if (tok.spec() == TokenSpec.ERC1155) {
            return tok.toIERC1155().balanceOf(user, tok.id());
        } else if (tok.spec() == TokenSpec.ERC721) {
            return tok.toIERC721().ownerOf(tok.id()) == user ? 1 : 0;
        } else if (tok == NATIVE_TOKEN) {
            return user.balance;
        }

        revert("invalid token");
    }

    function totalSupply(Token tok) internal view returns (uint256) {
        if (tok.spec() == TokenSpec.ERC20) {
            require(tok.id() == 0);
            return tok.toIERC20().totalSupply(); // ERC721 balanceOf() has the same signature
        } else if (tok.spec() == TokenSpec.ERC1155) {
            return ERC1155Supply(tok.addr()).totalSupply(tok.id());
        } else if (tok.spec() == TokenSpec.ERC721) {
            return 1;
        } else if (tok == NATIVE_TOKEN) {
            revert("ETH total supply unknown");
        }

        revert("invalid token");
    }

    function symbol(Token tok) internal view returns (string memory) {
        if (tok.spec() == TokenSpec.ERC20) {
            require(tok.id() == 0);
            return tok.toIERC20().symbol(); // ERC721 balanceOf() has the same signature
        } else if (tok.spec() == TokenSpec.ERC1155) {
            return "";
        } else if (tok.spec() == TokenSpec.ERC721) {
            return tok.toIERC721().symbol();
        } else if (tok == NATIVE_TOKEN) {
            return NATIVE_TOKEN_SYMBOL;
        }

        revert("invalid token");
    }

    function decimals(Token tok) internal view returns (uint8) {
        if (tok.spec() == TokenSpec.ERC20) {
            require(tok.id() == 0);
            return IERC20Metadata(tok.addr()).decimals();
        } else if (tok == NATIVE_TOKEN) {
            return 18;
        }
        return 0;
    }

    function transferFrom(Token tok, address from, address to, uint256 amount) internal {
        if (tok.spec() == TokenSpec.ERC20) {
            require(tok.id() == 0);
            if (from == address(this)) {
                tok.toIERC20().safeTransfer(to, amount);
            } else {
                tok.toIERC20().safeTransferFrom(from, to, amount);
            }
        } else if (tok == NATIVE_TOKEN) {
            require(from == address(this), "native token transferFrom is not supported");
            assembly {
                let success := call(gas(), to, amount, 0, 0, 0, 0)
                if iszero(success) { revert(0, 0) }
            }
        } else if (tok.spec() == TokenSpec.ERC721) {
            require(amount == 1, "invalid amount");
            tok.toIERC721().safeTransferFrom(from, to, tok.id());
        } else if (tok.spec() == TokenSpec.ERC1155) {
            tok.toIERC1155().safeTransferFrom(from, to, tok.id(), amount, "");
        } else {
            revert("invalid token");
        }
    }

    function meteredTransferFrom(Token tok, address from, address to, uint256 amount) internal returns (uint256) {
        uint256 balBefore = tok.balanceOf(to);
        tok.transferFrom(from, to, amount);
        return tok.balanceOf(to) - balBefore;
    }

    function safeTransferFrom(Token tok, address from, address to, uint256 amount) internal {
        require(tok.meteredTransferFrom(from, to, amount) >= amount);
    }
}
