pragma solidity ^0.5.17;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/upgrades/contracts/upgradeability/InitializableAdminUpgradeabilityProxy.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "../Governance/Claimable.sol";
import "../libraries/String.sol";
import "./RenERC20.sol";
import "./interfaces/IGateway.sol";
import "../libraries/CanReclaimTokens.sol";

import "./MintGatewayV2.sol";
import "../Governance/RenProxyAdmin.sol";

contract MintGatewayUpgrader is Ownable, CanReclaimTokens {
    RenProxyAdmin renProxyAdmin;
    MintGatewayLogicV2 newGatewayLogic;
    address previousAdminOwner;
    address newMintAuthority;

    constructor(
        RenProxyAdmin _renProxyAdmin,
        MintGatewayLogicV2 _newGatewayLogic,
        address _newMintAuthority
    ) public {
        Ownable.initialize(msg.sender);
        renProxyAdmin = _renProxyAdmin;
        newGatewayLogic = _newGatewayLogic;
        previousAdminOwner = renProxyAdmin.owner();
        newMintAuthority = _newMintAuthority;
    }

    function upgrade(MintGatewayLogicV2 gatewayInstance, bytes32 selectorHash)
        public
        onlyOwner
    {
        uint256 minimumBurnAmount = gatewayInstance.minimumBurnAmount();
        RenERC20LogicV1 token = gatewayInstance.token();
        address mintAuthority = gatewayInstance.mintAuthority();
        address feeRecipient = gatewayInstance.feeRecipient();
        uint16 mintFee = gatewayInstance.mintFee();
        uint16 burnFee = gatewayInstance.burnFee();
        uint256 nextN = gatewayInstance.nextN();

        address previousGatewayOwner = gatewayInstance.owner();
        gatewayInstance.claimOwnership();

        // Update implementation.
        renProxyAdmin.upgrade(
            AdminUpgradeabilityProxy(
                // Cast gateway instance to payable address
                address(uint160(address(gatewayInstance)))
            ),
            address(newGatewayLogic)
        );

        // Update mint authorities and selector hash.
        address legacyMintAuthority = gatewayInstance.mintAuthority();
        gatewayInstance.updateMintAuthority(newMintAuthority);
        gatewayInstance._legacy_updateMintAuthority(legacyMintAuthority);
        gatewayInstance.updateSelectorHash(selectorHash);

        require(
            gatewayInstance.minimumBurnAmount() == minimumBurnAmount,
            "Expected minimumBurnAmount to not change."
        );
        require(
            gatewayInstance.token() == token,
            "Expected token to not change."
        );
        require(
            gatewayInstance._legacy_mintAuthority() == mintAuthority,
            "Expected _legacy_mintAuthority to equal old mintAuthority."
        );
        require(
            gatewayInstance.mintAuthority() == newMintAuthority,
            "Expected mintAuthority to equal new mintAuthority."
        );
        require(
            gatewayInstance.feeRecipient() == feeRecipient,
            "Expected feeRecipient to not change."
        );
        require(
            gatewayInstance.mintFee() == mintFee,
            "Expected mintFee to not change."
        );
        require(
            gatewayInstance.burnFee() == burnFee,
            "Expected burnFee to not change."
        );
        require(
            gatewayInstance.nextN() == nextN,
            "Expected nextN to not change."
        );

        gatewayInstance._directTransferOwnership(previousGatewayOwner);
    }

    function done() public onlyOwner {
        renProxyAdmin.transferOwnership(previousAdminOwner);
    }
}
