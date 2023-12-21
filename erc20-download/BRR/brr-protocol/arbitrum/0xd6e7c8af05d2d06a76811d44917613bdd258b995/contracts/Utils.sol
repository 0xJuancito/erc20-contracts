pragma solidity ^0.8.0;

contract Utils{

    function increment(uint256 value) public view returns (uint256) {
        unchecked {
            return value += 1;
        }
    }

    function getPercentageOf(uint value, uint percentage) public view returns(uint){
        return value * percentage / 100;
    }

    function uint2str(uint256 _i)
        public
        view
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
