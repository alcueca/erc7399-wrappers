// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { Registry } from "src/Registry.sol";
import { Arrays } from "src/utils/Arrays.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract RegistryDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");
    address constant ULTRASECRETH = 0xAA62cBC86d65917a44EF1C1fae3AAB55fbd773C5;
    address constant ALCUECA = 0xbb807E3E765a9487F5F423C3555b329E755c1EEE;

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();
        Registry registry =
            new Registry{ salt: SALT }(Arrays.toArray(ULTRASECRETH, ALCUECA), Arrays.toArray(ALCUECA, ULTRASECRETH));
        console2.log("Registry deployed at %s", address(registry));
        vm.stopBroadcast();
    }
}
