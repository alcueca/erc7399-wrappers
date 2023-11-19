// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { Registry } from "lib/registry/src/Registry.sol";

import { AaveWrapper } from "src/aave/AaveWrapper.sol";
import { IPoolAddressesProviderV3 } from "src/aave/interfaces/IPoolAddressesProviderV3.sol";
import { IPoolAddressesProviderV2 } from "src/aave/interfaces/IPoolAddressesProviderV2.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract AaveDeploy is Script {
    enum Network {
        MAINNET,
        ARBITRUM,
        POLYGON,
        OPTIMISM,
        BASE,
        GNOSIS
    }

    struct AaveDeployParams {
        string name;
        address addressProvider;
        address poolDataProvider;
    }

    bytes32 public constant SALT = keccak256("alcueca-2");
    Network public constant NETWORK = Network.MAINNET;

    Registry internal registry = Registry(0x1BFf8Eee6ECF1c8155E81dba8894CE9cF49a220c);

    mapping(Network network => AaveDeployParams) public deployParams;

    constructor() {
        deployParams[Network.MAINNET] = AaveDeployParams({
            name: "AaveV3",
            addressProvider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e,
            poolDataProvider: address(0)
        });
        deployParams[Network.MAINNET] = AaveDeployParams({
            name: "Spark",
            addressProvider: 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE,
            poolDataProvider: address(0)
        });
        deployParams[Network.ARBITRUM] = AaveDeployParams({
            name: "AaveV3",
            addressProvider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
            poolDataProvider: address(0)
        });
        deployParams[Network.POLYGON] = AaveDeployParams({
            name: "AaveV3",
            addressProvider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
            poolDataProvider: address(0)
        });
        deployParams[Network.OPTIMISM] = AaveDeployParams({
            name: "AaveV3",
            addressProvider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
            poolDataProvider: address(0)
        });
        deployParams[Network.BASE] = AaveDeployParams({
            name: "AaveV3",
            addressProvider: 0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D,
            poolDataProvider: address(0)
        });
        deployParams[Network.GNOSIS] = AaveDeployParams({
            name: "AaveV3",
            addressProvider: 0x36616cf17557639614c1cdDb356b1B83fc0B2132,
            poolDataProvider: address(0)
        });
        deployParams[Network.GNOSIS] = AaveDeployParams({
            name: "Spark",
            addressProvider: 0xA98DaCB3fC964A6A0d2ce3B77294241585EAbA6d,
            poolDataProvider: address(0)
        });
        deployParams[Network.GNOSIS] = AaveDeployParams({
            name: "Agave",
            addressProvider: 0x3673C22153E363B1da69732c4E0aA71872Bbb87F,
            poolDataProvider: 0xE6729389DEa76D47b5BcB0bA5c080821c3B51329
        });
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();

        AaveDeployParams memory params = deployParams[NETWORK];
        bool isV2 = params.poolDataProvider != address(0);
        address poolDataProvider = isV2
            ? params.poolDataProvider
            : address(IPoolAddressesProviderV3(params.addressProvider).getPoolDataProvider());
        address pool = isV2
            ? IPoolAddressesProviderV2(params.addressProvider).getLendingPool()
            : IPoolAddressesProviderV3(params.addressProvider).getPool();

        bytes memory paramsBytes = abi.encode(pool, params.addressProvider, poolDataProvider, isV2);
        if (keccak256(registry.get("AaveV3Wrapper")) != keccak256(paramsBytes)) {
            registry.set("AaveV3Wrapper", paramsBytes);
        }

        console2.log("%sAave provider", params.name);
        AaveWrapper aaveWrapper = new AaveWrapper{salt: SALT}(registry, params.name);
        console2.log("%sWrapper deployed at: %s", params.name, address(aaveWrapper));

        vm.stopBroadcast();
    }
}
