// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { Registry } from "src/Registry.sol";

import { AlgebraWrapper, IAlgebraFactory } from "../src/algebra/AlgebraWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract AlgebraDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    struct Fork {
        string name;
        IAlgebraFactory factory;
        address weth;
        address usdc;
    }

    mapping(Network network => Fork fork) public forks;

    Registry internal registry = Registry(0xa348320114210b8F4eaF1b0795aa8F70803a93EA);

    constructor() {
        forks[ARBITRUM] = Fork({
            name: "CamelotWrapper",
            factory: IAlgebraFactory(0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B),
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
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
        AlgebraWrapper wrapper = new AlgebraWrapper{ salt: SALT }(key, registry);
        console2.log("AlgebraWrapper: %s", address(wrapper));
    }
}
