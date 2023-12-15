// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { Registry } from "lib/registry/src/Registry.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract RegistryDeploy is Script {
    bytes32 public constant SALT = keccak256("alcueca-1");

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();
        new Registry{ salt: SALT }(msg.sender);
        vm.stopBroadcast();
    }
}
