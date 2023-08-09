// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}
