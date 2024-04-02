// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { AlgebraPendleWrapper, IAlgebraFactory, IPendleRouterV3 } from "../src/pendle/AlgebraPendleWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract AlgebraPendleDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        IPendleRouterV3 pendleRouter = IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0);
        IAlgebraFactory factory = IAlgebraFactory(0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B);
        pendleRouter = IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0);
        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        console2.log("pendleRouter: %s", address(pendleRouter));
        console2.log("factory: %s", address(factory));
        console2.log("usdc: %s", usdc);
        console2.log("weth: %s", weth);

        vm.broadcast();
        AlgebraPendleWrapper wrapper =
            new AlgebraPendleWrapper{ salt: SALT }(msg.sender, factory, weth, usdc, pendleRouter);
        console2.log("AlgebraPendleWrapper: %s", address(wrapper));
    }
}
