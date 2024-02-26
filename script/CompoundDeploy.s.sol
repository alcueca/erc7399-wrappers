// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

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

    mapping(Network network => DeployParams params) public tokens;

    Registry internal registry = Registry(0xa348320114210b8F4eaF1b0795aa8F70803a93EA);

    constructor() {
        tokens[MAINNET] = DeployParams({
            name: "CompoundWrapper",
            balancer: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            comptroller: 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B,
            nativeToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            intermediateToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        });
        tokens[BASE] = DeployParams({
            name: "MoonwellWrapper",
            balancer: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            comptroller: 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C,
            nativeToken: 0x4200000000000000000000000000000000000006,
            intermediateToken: 0x4200000000000000000000000000000000000006
        });
        tokens[OPTIMISM] = DeployParams({
            name: "SonneWrapper",
            balancer: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            comptroller: 0x60CF091cD3f50420d50fD7f707414d0DF4751C58,
            nativeToken: 0x4200000000000000000000000000000000000006,
            intermediateToken: 0x4200000000000000000000000000000000000006
        });
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        Network network = currentNetwork();

        DeployParams memory deployParams = tokens[network];
        require(
            deployParams.balancer != address(0),
            string.concat("deployParams not set for chain ", vm.toString(block.chainid))
        );

        bytes memory paramsBytes = abi.encode(
            deployParams.balancer, deployParams.comptroller, deployParams.nativeToken, deployParams.intermediateToken
        );

        string memory key = deployParams.name;

        if (keccak256(registry.get(key)) != keccak256(paramsBytes)) {
            console2.log("Updating registry");
            vm.broadcast();
            registry.set(key, paramsBytes);
        }

        (address balancer, address comptroller, address nativeToken, address intermediateToken) =
            abi.decode(registry.get(key), (address, address, address, address));
        console2.log("balancer: %s", balancer);
        console2.log("comptroller: %s", comptroller);
        console2.log("nativeToken: %s", nativeToken);
        console2.log("intermediateToken: %s", intermediateToken);

        vm.broadcast();
        CompoundWrapper wrapper = new CompoundWrapper{ salt: SALT }(registry, key);
        console2.log("CompoundWrapper deployed at: %s", address(wrapper));

        vm.broadcast();
        wrapper.update(); // On Mainnet this uses too much gas, so markets should be set one by one
    }
}
