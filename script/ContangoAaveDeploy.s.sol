// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { Registry } from "src/Registry.sol";
import { RegistryDeploy } from "./RegistryDeploy.s.sol";

import { PermissionedAaveWrapper } from "src/aave/PermissionedAaveWrapper.sol";
import { IPoolAddressesProviderV3 } from "src/aave/interfaces/IPoolAddressesProviderV3.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract ContangoAaveDeploy is Script {
    struct AaveDeployParams {
        address addressProvider;
    }

    bytes32 public constant SALT = keccak256("ultrasecr.eth-2");

    Registry internal registry = Registry(0xa348320114210b8F4eaF1b0795aa8F70803a93EA);

    address public constant TIMELOCK = 0xc0939a4Ed0129bc5162F6f693935B3F72a46a90D;
    address public constant CONTANGO = 0x6Cae28b3D09D8f8Fc74ccD496AC986FC84C0C24E;

    mapping(Network network => IPoolAddressesProviderV3 addressProvider) public deployParams;

    constructor() {
        deployParams[MAINNET] = IPoolAddressesProviderV3(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        deployParams[ARBITRUM] = IPoolAddressesProviderV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        deployParams[POLYGON] = IPoolAddressesProviderV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        deployParams[OPTIMISM] = IPoolAddressesProviderV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        deployParams[BASE] = IPoolAddressesProviderV3(0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D);
        deployParams[GNOSIS] = IPoolAddressesProviderV3(0x36616cf17557639614c1cdDb356b1B83fc0B2132);
        deployParams[BSC] = IPoolAddressesProviderV3(0xff75B6da14FfbbfD355Daf7a2731456b3562Ba6D);
        deployParams[AVALANCHE] = IPoolAddressesProviderV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        deployParams[SCROLL] = IPoolAddressesProviderV3(0x69850D0B276776781C063771b161bd8894BCdD04);
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        Network network = currentNetwork();
        IPoolAddressesProviderV3 addressProvider = deployParams[network];

        require(address(addressProvider) != address(0), "No deploy params for this network");

        bool isV2 = false;
        address poolDataProvider = address(addressProvider.getPoolDataProvider());
        address pool = addressProvider.getPool();

        bytes memory paramsBytes = abi.encode(pool, addressProvider, poolDataProvider, isV2);
        string memory key = "AaveV3Wrapper";
        console2.log(key);

        if (address(registry).code.length == 0) {
            console2.log("Registry not deployed");
            RegistryDeploy deploy = new RegistryDeploy();
            deploy.run();
        }

        if (keccak256(registry.get(key)) != keccak256(paramsBytes)) {
            console2.log("Updating registry");
            vm.broadcast();
            registry.set(key, paramsBytes);
        }

        vm.broadcast();
        PermissionedAaveWrapper wrapper =
            new PermissionedAaveWrapper{ salt: SALT }(msg.sender, CONTANGO, registry, "AaveV3");
        console2.log("%s deployed at: %s", key, address(wrapper));

        require(wrapper.ADDRESSES_PROVIDER() == address(addressProvider), "AddressesProvider not set");
        require(wrapper.POOL() == pool, "Pool not set");
        require(address(wrapper.dataProvider()) == poolDataProvider, "PoolDataProvider not set");
    }
}
