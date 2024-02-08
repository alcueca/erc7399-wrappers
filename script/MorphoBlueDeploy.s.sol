// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { MorphoBlueWrapper, IMorpho } from "../src/morpho/MorphoBlueWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract MorphoBlueDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");
    IMorpho internal morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();

        console2.log("MorphoBlue: %s", address(morpho));
        MorphoBlueWrapper wrapper = new MorphoBlueWrapper{ salt: SALT }(morpho);
        console2.log("MorphoBlueWrapper deployed at: %s", address(wrapper));

        vm.stopBroadcast();
    }
}
