// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { AlgebraPendleWrapper, IAlgebraFactory, IPendleRouterV3 } from "../src/pendle/AlgebraPendleWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract AlgebraPendleDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    struct Fork {
        string name;
        IAlgebraFactory factory;
        address weth;
        address usdc;
        IPendleRouterV3 pendleRouter;
    }

    mapping(Network network => Fork[] forks) public forks;

    constructor() {
        forks[ARBITRUM].push(
            Fork({
                name: "CamelotPendleWrapper",
                factory: IAlgebraFactory(0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B),
                weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
                usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                pendleRouter: IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0)
            })
        );
    }

    function run() public {
        console2.log("Deploying as %s on %s", msg.sender, currentNetwork().toString());

        Fork[] memory _forks = forks[currentNetwork()];

        for (uint256 i = 0; i < _forks.length; i++) {
            Fork memory fork = _forks[i];

            console2.log("pendleRouter: %s", address(fork.pendleRouter));
            console2.log("factory: %s", address(fork.factory));
            console2.log("usdc: %s", fork.usdc);
            console2.log("weth: %s", fork.weth);

            if (
                computeCreate2Address(
                    SALT,
                    hashInitCode(
                        type(AlgebraPendleWrapper).creationCode,
                        abi.encode(msg.sender, fork.factory, fork.weth, fork.usdc, fork.pendleRouter)
                    )
                ).code.length > 0
            ) {
                console2.log("%s: already deployed", fork.name);
                continue;
            }

            vm.broadcast();
            AlgebraPendleWrapper wrapper = new AlgebraPendleWrapper{ salt: SALT }(
                msg.sender, fork.factory, fork.weth, fork.usdc, fork.pendleRouter
            );
            console2.log("%s: %s", fork.name, address(wrapper));
        }
    }
}
