// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { Registry } from "src/Registry.sol";

import { SiloWrapper, IFlashLoaner, ISiloLens, IERC20 } from "../src/silo/SiloWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract SiloDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        ISiloLens lens = ISiloLens(0x07b94eB6AaD663c4eaf083fBb52928ff9A15BE47);
        IFlashLoaner balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        IWETH9Arbitrum intermediateToken = IWETH9Arbitrum(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // IWETH9

        console2.log("lens: %s", address(lens));
        console2.log("balancer: %s", address(balancer));
        console2.log("intermediateToken: %s", address(intermediateToken));

        vm.startBroadcast();
        SiloWrapper wrapper = new SiloWrapper{ salt: SALT }(lens, balancer, intermediateToken);
        intermediateToken.depositTo{ value: 1e10 }(address(wrapper));
        vm.stopBroadcast();
    }
}

interface IWETH9Arbitrum is IERC20 {
    function depositTo(address to) external payable;
}
