// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity >=0.6.10;

/**
 * @dev Blockwell Quill, storing arbitrary data associated with accounts.
 *
 * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
 */
library BlockwellQuill {
    struct Data {
        mapping(address => bytes) data;
    }

    /**
     * @dev Set data on the account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function set(
        Data storage data,
        address account,
        bytes memory value
    ) internal {
        require(account != address(0));
        data.data[account] = value;
    }

    /**
     * @dev Get data on the account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function get(Data storage data, address account) internal view returns (bytes memory) {
        require(account != address(0));
        return data.data[account];
    }

    /**
     * @dev Convert and set string data on the account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function setString(
        Data storage data,
        address account,
        string memory value
    ) internal {
        data.data[address(account)] = bytes(value);
    }

    /**
     * @dev Get and convert string data on the account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getString(Data storage data, address account) internal view returns (string memory) {
        return string(data.data[address(account)]);
    }

    /**
     * @dev Convert and set uint256 data on the account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function setUint256(
        Data storage data,
        address account,
        uint256 value
    ) internal {
        data.data[address(account)] = abi.encodePacked(value);
    }

    /**
     * @dev Get and convert uint256 data on the account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getUint256(Data storage data, address account) internal view returns (uint256) {
        uint256 ret;
        bytes memory source = data.data[address(account)];
        assembly {
            ret := mload(add(source, 32))
        }
        return ret;
    }

    /**
     * @dev Convert and set address data on the account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function setAddress(
        Data storage data,
        address account,
        address value
    ) internal {
        data.data[address(account)] = abi.encodePacked(value);
    }

    /**
     * @dev Get and convert address data on the account.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getAddress(Data storage data, address account) internal view returns (address) {
        address ret;
        bytes memory source = data.data[address(account)];
        assembly {
            ret := mload(add(source, 20))
        }
        return ret;
    }
}
