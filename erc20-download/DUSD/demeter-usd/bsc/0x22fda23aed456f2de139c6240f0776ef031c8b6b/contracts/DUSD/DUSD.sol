// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.16;
pragma experimental ABIEncoderV2;

import "../Utils/SafeMath.sol";
import "../Manager/ManagerProxy.sol";

contract DUSD is ManagerProxy {
    using SafeMath for uint;

    // --- BEP20 Data ---
    string  public constant version  = "1";
    string  public name;
    string  public symbol;
    uint8   public decimals;
    uint256 public totalSupply;

    mapping (address => uint)                      public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;
    mapping (address => uint)                      public nonces;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);

    // --- EIP712 niceties ---
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                getChainId(),
                address(this)
            ));
    }

    // --- Token ---
    function transfer(address dst, uint wad) external ValidUDSDState OutBlacklist2(msg.sender, dst) returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad) public ValidUDSDState OutBlacklist3(msg.sender, src, dst) returns (bool)
    {
        require(balanceOf[src] >= wad, "DUSD/insufficient-balance");
        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad, "DUSD/insufficient-allowance");
            allowance[src][msg.sender] = allowance[src][msg.sender].sub(wad);
        }
        balanceOf[src] = balanceOf[src].sub(wad);
        balanceOf[dst] = balanceOf[dst].add(wad);
        emit Transfer(src, dst, wad);
        return true;
    }

    function mint(address usr, uint wad) external ValidUDSDState CheckPermitsOr(_getMintRoles()) OutBlacklist2(msg.sender, usr) {
        balanceOf[usr] = balanceOf[usr].add(wad);
        totalSupply = totalSupply.add(wad);
        emit Transfer(address(0), usr, wad);
    }

    function burn(address usr, uint wad) external ValidUDSDState OutBlacklist2(msg.sender, usr) {
        require(balanceOf[usr] >= wad, "DUSD/insufficient-balance");
        if (usr != msg.sender && allowance[usr][msg.sender] != uint(-1)) {
            require(allowance[usr][msg.sender] >= wad, "DUSD/insufficient-allowance");
            allowance[usr][msg.sender] = allowance[usr][msg.sender].sub(wad);
        }
        balanceOf[usr] = balanceOf[usr].sub(wad);
        totalSupply = totalSupply.sub(wad);
        emit Transfer(usr, address(0), wad);
    }

    function approve(address usr, uint wad) external ValidUDSDState OutBlacklist2(msg.sender, usr) returns (bool) {
        allowance[msg.sender][usr] = wad;
        emit Approval(msg.sender, usr, wad);
        return true;
    }

    // --- Alias ---
    function push(address usr, uint wad) external {
        transferFrom(msg.sender, usr, wad);
    }

    function pull(address usr, uint wad) external {
        transferFrom(usr, msg.sender, wad);
    }

    function move(address src, address dst, uint wad) external {
        transferFrom(src, dst, wad);
    }

    // --- Approve by signature ---
    struct PermitParam {
        address holder;
        address spender;
        uint256 nonce;
        uint256 expiry;
        bool allowed;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function permit(PermitParam calldata param) external ValidUDSDState OutBlacklist3(msg.sender, param.holder, param.spender)
    {
        bytes32 digest = keccak256(abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH,
                    param.holder,
                    param.spender,
                    param.nonce,
                    param.expiry,
                    param.allowed))
            ));

        require(param.holder != address(0), "DUSD/invalid-address-0");
        require(param.holder == ecrecover(digest, param.v, param.r, param.s), "DUSD/invalid-permit");
        require(param.expiry == 0 || now <= param.expiry, "DUSD/permit-expired");
        require(param.nonce == nonces[param.holder]++, "DUSD/invalid-nonce");
        uint wad = param.allowed ? uint(-1) : 0;
        allowance[param.holder][param.spender] = wad;
        emit Approval(param.holder, param.spender, wad);
    }


    // --- internal ---
    function _getMintRoles() internal returns(string[] memory) {
        string[] memory roles = new string[](2);
        roles[0] = "DUSDMinter";
        roles[1] = "DUSDAdmin";
        return roles;
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

