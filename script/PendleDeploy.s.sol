// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { BalancerPendleWrapper, IFlashLoaner, IPendleRouterV3 } from "../src/pendle/BalancerPendleWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract PendleDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        IPendleRouterV3 pendleRouter = IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0);
        IFlashLoaner balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

        console2.log("pendleRouter: %s", address(pendleRouter));
        console2.log("balancer: %s", address(balancer));

        vm.broadcast();
        BalancerPendleWrapper wrapper = new BalancerPendleWrapper{ salt: SALT }(balancer, pendleRouter);
        console2.log("BalancerPendleWrapper: %s", address(wrapper));
    }
}
