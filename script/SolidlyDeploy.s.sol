// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { Registry } from "src/Registry.sol";

import { SolidlyWrapper } from "../src/solidly/SolidlyWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract SolidlyDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    struct Fork {
        string name;
        address factory;
        address weth;
        address usdc;
    }

    mapping(Network network => Fork fork) public forks;

    Registry internal registry = Registry(0xa348320114210b8F4eaF1b0795aa8F70803a93EA);

    constructor() {
        forks[BASE] = Fork({
            name: "AerodromeWrapper",
            factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da,
            weth: 0x4200000000000000000000000000000000000006,
            usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
        });
        forks[OPTIMISM] = Fork({
            name: "VelodromeWrapper",
            factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a,
            weth: 0x4200000000000000000000000000000000000006,
            usdc: 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85
        });
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        Network network = currentNetwork();

        Fork memory fork = forks[network];
        require(fork.weth != address(0), "Fork not supported");

        bytes memory paramsBytes = abi.encode(fork.factory, fork.weth, fork.usdc);

        string memory key = fork.name;

        if (keccak256(registry.get(key)) != keccak256(paramsBytes)) {
            console2.log("Updating registry");
            vm.broadcast();
            registry.set(key, paramsBytes);
        }

        (address _factory, address _weth, address _usdc) = abi.decode(registry.get(key), (address, address, address));
        console2.log("Factory: %s", _factory);
        console2.log("WETH: %s", _weth);
        console2.log("USDC: %s", _usdc);

        vm.broadcast();
        SolidlyWrapper wrapper = new SolidlyWrapper{ salt: SALT }(key, registry);
        console2.log("SolidlyWrapper deployed at: %s", address(wrapper));
    }
}
