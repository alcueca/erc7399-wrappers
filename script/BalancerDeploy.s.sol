// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { BalancerWrapper, IFlashLoaner } from "../src/balancer/BalancerWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract BalancerDeploy is Script {
    bytes32 public constant SALT = keccak256("alcueca-2");
    IFlashLoaner internal balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();

        console2.log("Balancer: %s", address(balancer));
        BalancerWrapper balancerWrapper = new BalancerWrapper{salt: SALT}(balancer);
        console2.log("BalancerWrapper deployed at: %s", address(balancerWrapper));

        vm.stopBroadcast();
    }
}
