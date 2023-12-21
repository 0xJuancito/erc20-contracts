// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "../ERC20Chainable.sol";
import "../../../v2/mapping/IMapping.sol";

contract Friend is ERC20Burnable, ERC20Chainable {

    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    address public crossMinter;

    uint256 public immutable genesisTs;
    uint256 public constant GENESIS_SUPPLY = 1_000_000_000_000 ether;
    uint256 public constant FIXED_INFLATE_YEAR = 102;

    uint256 public constant SECONDS_IN_DAY = 3_600 * 24;
    uint256 public constant DAYS_IN_YEAR = 365;
    uint256 public constant SECONDS_IN_YEAR = DAYS_IN_YEAR * SECONDS_IN_DAY;
    
    mapping(bytes32 => mapping(address => mapping(bytes32 => uint256))) public roundClaimed;
    mapping(bytes32 => uint256) public roundDistribution;

    constructor(address _minter) ERC20("Friend", "FREN") {
        require(_minter != address(0), "require valid minter");
        crossMinter = _minter;
        genesisTs = block.timestamp;
    }

    modifier onlyMinter() {
        require(msg.sender == crossMinter);
        _;
    }

    function crossIn(bytes32 _merkleRoot, uint256 _amount) external onlyMinter {
        require(roundDistribution[_merkleRoot] == 0, "existed round data");
        require(_amount > 0, "forbid zero amount");

        roundDistribution[_merkleRoot] = _amount;
        emit CrossIn(_merkleRoot, _amount);
    }

    function claim(bytes32 _merkleRoot, bytes32 _origin, uint256 _chainId, uint256 _amount, bytes32[] calldata _proof) external {
        require(roundDistribution[_merkleRoot] > 0, "unavailable round");
        require(checkHolder(_merkleRoot, _origin, _chainId, _amount, _proof), "invalid user or amount for claiming");
        require(totalSupply() + _amount <= currentQuota(), "exceed max total supply");
        require(roundClaimed[_merkleRoot][msg.sender][_origin] == 0, "already claimed");

        roundClaimed[_merkleRoot][msg.sender][_origin] = _amount;
        _mint(msg.sender, _amount);
    }
    
    function currentQuota() public view returns(uint256) {
        return computeQuota(block.timestamp);
    }

    /*
     * TotalSupply = GENESIS_SUPPLY * (1 + 2%)^yearExp
     */
    function computeQuota(uint256 _cmts) public view returns(uint256){
        uint256 secDiff = _cmts - genesisTs;
        uint256 expN = secDiff / SECONDS_IN_YEAR;    /* launch year towards zero */

        return GENESIS_SUPPLY * (FIXED_INFLATE_YEAR ** expN) / (100 ** expN);
    }

    /*
     * Merkle Cool
     */
    function _verify(bytes32 _merkleRoot, bytes32 _leaf, bytes32[] calldata proof) internal pure returns(bool) {
        return MerkleProof.verify(proof, _merkleRoot, _leaf);
    }

    function checkHolder(bytes32 _merkleRoot, bytes32 _origin, uint256 _chainId, uint256 _amount, bytes32[] calldata _proof) view public returns(bool){
        return _verify(_merkleRoot, leaf(msg.sender, _origin, _chainId, _amount), _proof);
    }

    function leaf(address _holder, bytes32 _origin, uint256 _chainId, uint256 _amount) public pure returns(bytes32) {
        return keccak256(abi.encode(
            _holder, _origin, _chainId, _amount
        ));
    }
}