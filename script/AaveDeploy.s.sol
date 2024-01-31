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

    mapping(Network network => AaveDeployParams[]) public deployParams;

    constructor() {
        deployParams[Network.MAINNET].push(
            AaveDeployParams({
                name: "AaveV3",
                addressProvider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e,
                poolDataProvider: address(0)
            })
        );
        deployParams[Network.MAINNET].push(
            AaveDeployParams({
                name: "Spark",
                addressProvider: 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE,
                poolDataProvider: address(0)
            })
        );
        deployParams[Network.ARBITRUM].push(
            AaveDeployParams({
                name: "AaveV3",
                addressProvider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
                poolDataProvider: address(0)
            })
        );
        deployParams[Network.POLYGON].push(
            AaveDeployParams({
                name: "AaveV3",
                addressProvider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
                poolDataProvider: address(0)
            })
        );
        deployParams[Network.OPTIMISM].push(
            AaveDeployParams({
                name: "AaveV3",
                addressProvider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
                poolDataProvider: address(0)
            })
        );
        deployParams[Network.BASE].push(
            AaveDeployParams({
                name: "AaveV3",
                addressProvider: 0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D,
                poolDataProvider: address(0)
            })
        );
        deployParams[Network.GNOSIS].push(
            AaveDeployParams({
                name: "AaveV3",
                addressProvider: 0x36616cf17557639614c1cdDb356b1B83fc0B2132,
                poolDataProvider: address(0)
            })
        );
        deployParams[Network.GNOSIS].push(
            AaveDeployParams({
                name: "Spark",
                addressProvider: 0xA98DaCB3fC964A6A0d2ce3B77294241585EAbA6d,
                poolDataProvider: address(0)
            })
        );
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        AaveDeployParams[] memory _params = deployParams[NETWORK];

        for (uint256 i = 0; i < _params.length; i++) {
            AaveDeployParams memory params = _params[i];

            bool isV2 = params.poolDataProvider != address(0);
            address poolDataProvider = isV2
                ? params.poolDataProvider
                : address(IPoolAddressesProviderV3(params.addressProvider).getPoolDataProvider());
            address pool = isV2
                ? IPoolAddressesProviderV2(params.addressProvider).getLendingPool()
                : IPoolAddressesProviderV3(params.addressProvider).getPool();

            bytes memory paramsBytes = abi.encode(pool, params.addressProvider, poolDataProvider, isV2);
            string memory key = string.concat(params.name, "Wrapper");
            console2.log(key);
            if (keccak256(registry.get(key)) != keccak256(paramsBytes)) {
                // vm.broadcast();
                // vm.prank(0xfA6DaAF31F8E2498b5D4C43E59c6eDd345D951F5);
                // registry.set(key, paramsBytes);
                console2.logBytes(abi.encodeWithSelector(registry.set.selector, key, paramsBytes));
            }

            vm.broadcast();
            AaveWrapper aaveWrapper = new AaveWrapper{ salt: SALT }(registry, params.name);
            console2.log(" deployed at: %s", key, address(aaveWrapper));
        }
    }
}
