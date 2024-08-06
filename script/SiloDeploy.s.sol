// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { IWETH9 } from "src/dependencies/IWETH9.sol";

import { SiloWrapper, IFlashLoaner, ISiloLens } from "../src/silo/SiloWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract SiloDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    struct Deployment {
        Network network;
        IWETH9 weth;
        ISiloLens lens;
    }

    Deployment[] public deployments;

    constructor() {
        deployments.push(
            Deployment({
                network: ARBITRUM,
                weth: IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
                lens: ISiloLens(0x07b94eB6AaD663c4eaf083fBb52928ff9A15BE47)
            })
        );
        deployments.push(
            Deployment({
                network: OPTIMISM,
                weth: IWETH9(0x4200000000000000000000000000000000000006),
                lens: ISiloLens(0xd3De080436b9d38DC315944c16d89C050C414Fed)
            })
        );
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        IFlashLoaner balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        Network network = currentNetwork();

        for (uint256 i = 0; i < deployments.length; i++) {
            Deployment memory deployment = deployments[i];
            if (deployment.network != network) continue;

            console2.log("lens: %s", address(deployment.lens));
            console2.log("balancer: %s", address(balancer));
            console2.log("weth: %s", address(deployment.weth));

            vm.startBroadcast();
            SiloWrapper wrapper = new SiloWrapper{ salt: SALT }(deployment.lens, balancer, deployment.weth);
            deployment.weth.deposit{ value: 1e10 }();
            deployment.weth.transfer(address(wrapper), 1e10);
            vm.stopBroadcast();

            console2.log("Deployed SiloWrapper at %s", address(wrapper));
        }
    }
}
