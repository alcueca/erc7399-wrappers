// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { UniswapV3PendleWrapper, IPendleRouterV3 } from "../src/pendle/UniswapV3PendleWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract UniswapV3PendleDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    mapping(Network network => mapping(bytes32 token => address)) public tokens;

    address internal factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    IPendleRouterV3 internal pendleRouter = IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0);

    function run() public {
        console2.log("Deploying as %s on %s", msg.sender, currentNetwork().toString());

        vm.broadcast();
        UniswapV3PendleWrapper uniswapV3Wrapper =
            new UniswapV3PendleWrapper{ salt: SALT }(msg.sender, factory, weth, pendleRouter);
        console2.log("UniswapV3PendleWrapper deployed at: %s", address(uniswapV3Wrapper));
    }
}
