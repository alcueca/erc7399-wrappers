// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { MorphoPendleWrapper, IMorpho, IPendleRouterV3 } from "../src/pendle/MorphoPendleWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract MorphoPendleDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        IPendleRouterV3 pendleRouter = IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0);

        console2.log("pendleRouter: %s", address(pendleRouter));
        console2.log("morpho: %s", address(morpho));

        vm.broadcast();
        MorphoPendleWrapper wrapper = new MorphoPendleWrapper{ salt: SALT }(morpho, pendleRouter);
        console2.log("MorphoPendleWrapper: %s", address(wrapper));
    }
}
