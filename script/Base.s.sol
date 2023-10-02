// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    modifier broadcast(string memory fork) {
        vm.createSelectFork(fork);
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}
