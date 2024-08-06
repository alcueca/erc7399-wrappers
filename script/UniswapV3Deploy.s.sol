// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { Registry } from "src/Registry.sol";

import { UniswapV3Wrapper } from "../src/uniswapV3/UniswapV3Wrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract UniswapV3Deploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    struct Deployment {
        string key;
        Network network;
        address factory;
        address weth;
        address usdc;
        address usdt;
    }

    Deployment[] public deployments;

    Registry internal registry = Registry(0xa348320114210b8F4eaF1b0795aa8F70803a93EA);

    constructor() {
        deployments.push(
            Deployment({
                key: "UniswapV3Wrapper",
                network: MAINNET,
                factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
                weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                usdt: 0xdAC17F958D2ee523a2206206994597C13D831ec7
            })
        );
        deployments.push(
            Deployment({
                key: "UniswapV3Wrapper",
                network: ARBITRUM,
                factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
                weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
                usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                usdt: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9
            })
        );
        deployments.push(
            Deployment({
                key: "UniswapV3Wrapper",
                network: POLYGON,
                factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
                weth: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
                usdc: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
                usdt: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F
            })
        );
        deployments.push(
            Deployment({
                key: "UniswapV3Wrapper",
                network: OPTIMISM,
                factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
                weth: 0x4200000000000000000000000000000000000006,
                usdc: 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85,
                usdt: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58
            })
        );
        deployments.push(
            Deployment({
                key: "CanonicalWrapper",
                network: OPTIMISM,
                factory: 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F,
                weth: 0x4200000000000000000000000000000000000006,
                usdc: 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85,
                usdt: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58
            })
        );
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        Network network = currentNetwork();

        for (uint256 i = 0; i < deployments.length; i++) {
            Deployment memory deployment = deployments[i];
            if (deployment.network != network) continue;

            bytes memory paramsBytes = abi.encode(deployment.factory, deployment.weth, deployment.usdc, deployment.usdt);

            string memory key = deployment.key;

            if (keccak256(registry.get(key)) != keccak256(paramsBytes)) {
                console2.log("Updating registry");
                vm.broadcast();
                registry.set(key, paramsBytes);
            }

            (address _factory, address _weth, address _usdc, address _usdt) =
                abi.decode(registry.get(key), (address, address, address, address));
            console2.log("Factory: %s", _factory);
            console2.log("WETH: %s", _weth);
            console2.log("USDC: %s", _usdc);
            console2.log("USDT: %s", _usdt);

            vm.broadcast();
            UniswapV3Wrapper uniswapV3Wrapper = new UniswapV3Wrapper{ salt: SALT }(key, registry);
            console2.log("%s deployed at: %s", key, address(uniswapV3Wrapper));
        }
    }
}
