// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { Registry } from "src/Registry.sol";

import { CompoundWrapper } from "../src/compound/CompoundWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract CompoundDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    struct DeployParams {
        string name;
        address balancer;
        address comptroller;
        address nativeToken;
        address intermediateToken;
    }

    mapping(uint256 network => DeployParams) public tokens;

    Registry internal registry = Registry(0x1BFf8Eee6ECF1c8155E81dba8894CE9cF49a220c);

    constructor() {
        tokens[1] = DeployParams({
            name: "CompoundWrapper",
            balancer: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            comptroller: 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B,
            nativeToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            intermediateToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        });
        tokens[8453] = DeployParams({
            name: "MoonwellWrapper",
            balancer: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            comptroller: 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C,
            nativeToken: 0x4200000000000000000000000000000000000006,
            intermediateToken: 0x4200000000000000000000000000000000000006
        });
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();
        DeployParams memory deployParams = tokens[block.chainid];
        require(
            deployParams.balancer != address(0),
            string.concat("deployParams not set for chain ", vm.toString(block.chainid))
        );

        bytes memory params = abi.encode(
            deployParams.balancer, deployParams.comptroller, deployParams.nativeToken, deployParams.intermediateToken
        );
        if (keccak256(registry.get(deployParams.name)) != keccak256(params)) {
            registry.set(deployParams.name, params);
        }

        (address balancer, address comptroller, address nativeToken, address intermediateToken) =
            abi.decode(registry.get(deployParams.name), (address, address, address, address));
        console2.log("balancer: %s", balancer);
        console2.log("comptroller: %s", comptroller);
        console2.log("nativeToken: %s", nativeToken);
        console2.log("intermediateToken: %s", intermediateToken);

        CompoundWrapper wrapper = new CompoundWrapper{ salt: SALT }(registry, deployParams.name);
        console2.log("CompoundWrapper deployed at: %s", address(wrapper));

        wrapper.update(); // On Mainnet this uses too much gas, so markets should be set one by one

        vm.stopBroadcast();
    }
}
