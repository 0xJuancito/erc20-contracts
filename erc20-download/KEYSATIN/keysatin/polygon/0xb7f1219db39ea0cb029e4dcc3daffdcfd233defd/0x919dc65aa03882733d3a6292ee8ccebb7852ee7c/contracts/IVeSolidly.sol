// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IVeSolidly {
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Deposit(
        address indexed provider,
        uint256 tokenId,
        uint256 value,
        uint256 indexed locktime,
        uint8 depositType,
        uint256 ts
    );
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Withdraw(address indexed provider, uint256 tokenId, uint256 value, uint256 ts);

    function abstain(uint256 _tokenId) external;

    function approve(address _approved, uint256 _tokenId) external;

    function attachToken(uint256 _tokenId) external;

    function attachments(uint256) external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function balanceOfAtNFT(uint256 _tokenId, uint256 _block) external view returns (uint256);

    function balanceOfNFT(uint256 _tokenId) external view returns (uint256);

    function balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256);

    function block_number() external view returns (uint256);

    function checkpoint() external;

    function controller() external view returns (address);

    function createLock(uint256 _value, uint256 _lockDuration) external returns (uint256);
    function create_lock(uint256 _value, uint256 _lockDuration) external returns (uint256);
    function createLockFor(
        uint256 _value,
        uint256 _lockDuration,
        address _to
    ) external returns (uint256);

    function decimals() external view returns (uint8);

    function depositFor(uint256 _tokenId, uint256 _value) external;

    function detachToken(uint256 _tokenId) external;

    function epoch() external view returns (uint256);

    function getApproved(uint256 _tokenId) external view returns (address);

    function getLastUserSlope(uint256 _tokenId) external view returns (int128);

    function increaseAmount(uint256 _tokenId, uint256 _value) external;
    function increase_amount(uint256 _tokenId, uint256 _value) external;

    function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration) external;
    function increase_unlock_time(uint256 _tokenId, uint256 _lockDuration) external;

    function isApprovedForAll(address _owner, address _operator) external view returns (bool);

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool);

    function locked(uint256) external view returns (int128 amount, uint256 end);

    function lockedEnd(uint256 _tokenId) external view returns (uint256);
    function locked__end(uint256 _tokenId) external view returns (uint256);

    function merge(uint256 _from, uint256 _to) external;

    function name() external view returns (string memory);

    function ownerOf(uint256 _tokenId) external view returns (address);

    function ownershipChange(uint256) external view returns (uint256);

    function pointHistory(uint256 _loc) external view returns (IVe.Point memory);

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) external;

    function setApprovalForAll(address _operator, bool _approved) external;

    function slopeChanges(uint256) external view returns (int128);

    function supportsInterface(bytes4 _interfaceID) external view returns (bool);

    function symbol() external view returns (string memory);

    function token() external view returns (address);

    function tokenOfOwnerByIndex(address _owner, uint256 _tokenIndex) external view returns (uint256);

    function tokenURI(uint256 _tokenId) external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function totalSupplyAt(uint256 _block) external view returns (uint256);

    function totalSupplyAtT(uint256 t) external view returns (uint256);

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    function userPointEpoch(uint256) external view returns (uint256);

    function userPointHistory(uint256 _tokenId, uint256 _loc) external view returns (IVe.Point memory);

    function userPointHistoryTs(uint256 _tokenId, uint256 _idx) external view returns (uint256);

    function version() external view returns (string memory);

    function voted(uint256) external view returns (bool);

    function voting(uint256 _tokenId) external;

    function withdraw(uint256 _tokenId) external;
}

interface IVe {
    struct Point {
        int128 bias;
        int128 slope;
        uint256 ts;
        uint256 blk;
    }
}